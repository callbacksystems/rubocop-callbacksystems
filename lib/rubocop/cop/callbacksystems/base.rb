class RuboCop::Cop::Callbacksystems::Base < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::Helpers

  exclude_from_registry

  def add_offense(node_or_range, message: nil, severity: nil, rewrites_comments: false, &correction)
    if autocorrect? && !flushing_corrections?
      request = CorrectionRequest.new \
        range_from_node_or_range(node_or_range), message:, severity:, correction:, rewrites_comments: rewrites_comments
      if reserve(request.range)
        correction_queue.add(request, enabled: correction_enabled?(request.range))
      end
    else
      super(node_or_range, message:, severity:, &correction)
    end
  end

  def on_investigation_end
    flush_corrections
    super
  end

  private
    def flushing_corrections?
      correction_queue.flushing?
    end

    def correction_queue
      @correction_queue ||= CorrectionQueue.new
    end

    def reserve(range)
      reserved_locations.add?(range)
    end

    def reserved_locations
      if @reservation_source != processed_source
        @reservation_source = processed_source
        @reserved_locations = Set.new
      end
      @reserved_locations
    end

    def correction_enabled?(range)
      if processed_source.comment_config.respond_to?(:cop_enabled_at_lines?)
        range.first_line.upto(range.last_line).all? { enabled_line?(it) }
      else
        enabled_line?(range.first_line)
      end
    end

    def flush_corrections
      correction_queue.flush(processed_source) do |offense, correction|
        add_offense offense.range, message: offense.message, severity: offense.severity, &correction
      end
    end

    def source_comments
      RuboCop::Callbacksystems::Source::Comments.for(processed_source)
    end

    def project_root
      @config.base_dir_for_path_parameters
    end

    # Measuring against any width but the enforced one leaves two corrections undoing each other.
    def max_line_length
      config.for_cop("Layout/LineLength")["Max"]
    end

    def report(analysis, rewrites_comments: false)
      offense = analysis.offense
      add_offense(offense.range, message: offense.message, rewrites_comments:, &offense.correction) if offense
    end

    def report_each(analyses, rewrites_comments: false)
      analyses.each_offense do |offense|
        add_offense(offense.range, message: offense.message, rewrites_comments:, &offense.correction)
      end
    end

    class CorrectionRequest
      attr_reader :range, :message, :severity, :correction

      def initialize(range, message:, severity:, correction:, rewrites_comments:)
        @range = range
        @message = message
        @severity = severity
        @correction = correction
        @rewrites_comments = rewrites_comments
      end

      def batchable?(enabled:)
        correction && enabled
      end

      def rewrites_comments?
        rewrites_comments
      end

      private
        attr_reader :rewrites_comments
    end

    class CorrectionQueue
      def initialize
        @offenses = []
        @corrections = []
        @flushing = false
      end

      def add(request, enabled:)
        offenses << request
        corrections << request if request.batchable?(enabled:)
      end

      def flushing?
        flushing
      end

      def flush(processed_source)
        batch = RuboCop::Callbacksystems::Autocorrection::Batch.new(corrections, processed_source)
        @flushing = true
        offenses.each { yield it, batch.correction_for(it) }
      ensure
        @flushing = false
        offenses.clear
        corrections.clear
      end

      private
        attr_reader :offenses, :corrections, :flushing
    end
end
