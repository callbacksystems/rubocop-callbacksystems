class CoverageReport
  MINIMUM = 99
  KINDS = %i[ lines branches methods ]

  def initialize(results, root)
    @results = results
    @root = root
  end

  def text
    [ *measures.map(&:summary), "", *shortfalls ].join("\n")
  end

  def met?
    measures.all?(&:met?)
  end

  private
    attr_reader :results, :root

    def measures
      @measures ||= KINDS.map { Measure.new(it, own_files) }
    end

    def own_files
      @own_files ||= results.filter_map do |path, coverage|
        [ path.delete_prefix(root_prefix), coverage ] if path.start_with?(root_prefix)
      end.to_h
    end

    def root_prefix
      "#{root}/"
    end

    def shortfalls
      measures.flat_map do |measure|
        measure.shortfalls.sort_by { |path, count| [ -count, path ] }.first(10).map do |path, count|
          format("  %<count>3d %<kind>-9s %<path>s", count:, kind: measure.kind, path:)
        end
      end
    end

    class Measure
      attr_reader :kind

      def initialize(kind, files)
        @kind = kind
        @files = files
      end

      def summary
        format \
          "%<kind>-9s %<reached>5d/%<total>-5d %<share>6.2f%%%<flag>s",
          kind: kind, reached: reached, total: total, share: share, flag: met? ? "" : "  under"
      end

      def met?
        share >= MINIMUM
      end

      def shortfalls
        files.filter_map do |path, data|
          counters_in(data).count(&:zero?).then { [ path, it ] if it.positive? }
        end
      end

      private
        attr_reader :files

        def reached
          counters.count(&:positive?)
        end

        def counters
          @counters ||= files.values.flat_map { counters_in(it) }
        end

        def counters_in(data)
          case kind
          when :lines then data[:lines].compact
          when :branches then data[:branches].values.flat_map(&:values)
          when :methods then data[:methods].values
          end
        end

        def total
          counters.size
        end

        def share
          total.zero? ? 100.0 : 100.0 * reached / total
        end
    end
end
