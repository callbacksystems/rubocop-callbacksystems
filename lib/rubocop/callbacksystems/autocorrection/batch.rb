# Corrections from one cop rehearsed together. The common path parses the rewritten file once. When preserving comments
# fails, every entry must have a safe form and their exact aggregate must pass a second rehearsal. A batch is atomic
# because its entries may depend on each other in ways syntax and comment checks cannot see.
class RuboCop::Callbacksystems::Autocorrection::Batch
  BYPASS_DEPTH = :rubocop_callbacksystems_correction_batch_bypass_depth

  class << self
    # The audit reads what a correction does on its own, so a cop that declines can be told from one held back.
    def bypassing
      Thread.current.thread_variable_set(BYPASS_DEPTH, bypass_depth + 1)
      yield
    ensure
      Thread.current.thread_variable_set(BYPASS_DEPTH, bypass_depth - 1)
    end

    def bypassed?
      bypass_depth.positive?
    end

    private
      def bypass_depth
        Thread.current.thread_variable_get(BYPASS_DEPTH).to_i
      end
  end

  def initialize(entries, processed_source)
    @entries = entries
    @processed_source = processed_source
  end

  def correction_for(entry)
    corrections[entry]
  end

  private
    attr_reader :entries, :processed_source

    def corrections
      self.class.bypassed? ? bypassed_corrections : accepted_corrections
    end

    def bypassed_corrections
      @bypassed_corrections ||= selected_corrections
    end

    def selected_corrections
      Selection.new(entries, processed_source).corrections
    end

    def accepted_corrections
      @accepted_corrections ||= selected_corrections
    end

    class Selection
      attr_reader :corrections

      def initialize(entries, processed_source)
        @entries = entries
        @processed_source = processed_source
        @corrections = {}.compare_by_identity
        selected.each { |entry, correction| corrections[entry] = correction }
      end

      private
        attr_reader :entries, :processed_source

        def selected
          if accepts?(as_written) then as_written
          elsif rescued_corrections_accepted? then rescued
          else []
          end
        end

        def accepts?(candidates)
          rehearsal = RuboCop::Callbacksystems::Autocorrection::Rehearsal.new \
            combined_correction(candidates), processed_source
          RuboCop::Callbacksystems::Autocorrection::Batch.bypassed? || rehearsal.empty? ||
            (rehearsal.parses? && (rewrites_comments? || rehearsal.keeps_comments?))
        rescue Parser::ClobberingError
          false
        end

        def combined_correction(candidates)
          ->(corrector) { candidates.each { it.last.call(corrector) } }
        end

        def rewrites_comments?
          entries.all? { it.respond_to?(:rewrites_comments?) && it.rewrites_comments? }
        end

        def as_written
          @as_written ||= entries.map { [ it, it.correction ] }
        end

        def rescued_corrections_accepted?
          !rewrites_comments? && rescued && accepts?(rescued)
        end

        def rescued
          @rescued ||= RehearsedCandidates.new(entries, processed_source).to_a
        end

        class RehearsedCandidates
          def initialize(entries, processed_source)
            @entries = entries
            @processed_source = processed_source
          end

          def to_a
            candidates if candidates.size == entries.size
          end

          private
            attr_reader :entries, :processed_source

            def candidates
              @candidates ||= entries.lazy.map { candidate_for(it) }.take_while(&:last).to_a
            end

            def candidate_for(entry)
              [ entry, preserving_comments_in(entry) ]
            end

            def preserving_comments_in(entry)
              comment_rescue_for(entry).preserving(entry.correction)
            end

            def comment_rescue_for(entry)
              RuboCop::Callbacksystems::Autocorrection::CommentRescue.new \
                RuboCop::Callbacksystems::Autocorrection::Rehearsal.new(entry.correction, processed_source),
                processed_source
            end
        end
    end
end
