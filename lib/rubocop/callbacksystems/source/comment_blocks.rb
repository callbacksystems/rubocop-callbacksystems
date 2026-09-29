# The unit the comment cops reason about: consecutive own-line `#` lines starting at the same column, two or more of
# them, leaving out what addresses the tooling rather than the reader.
class RuboCop::Callbacksystems::Source::CommentBlocks
  include Enumerable
  include RuboCop::Callbacksystems::Helpers

  delegate :each, to: :blocks

  def initialize(processed_source, reject_tooling_runs: false)
    @processed_source = processed_source
    @reject_tooling_runs = reject_tooling_runs
  end

  private
    attr_reader :processed_source, :reject_tooling_runs

    def blocks
      comment_runs.flat_map { blocks_in(it) }
    end

    def comment_runs
      own_line_comments.chunk_while { |previous, comment| continues?(previous, comment) }
    end

    def own_line_comments
      processed_source.comments.select { it.inline? && own_line_comment?(it) }
    end

    def continues?(previous, comment)
      comment.source_range.line == previous.source_range.line + 1 &&
        comment.source_range.column == previous.source_range.column
    end

    def blocks_in(run)
      if reject_tooling_runs && run.any? { tooling_comment?(it) }
        []
      else
        run.reject { tooling_comment?(it) }
          .chunk_while { |previous, comment| continues?(previous, comment) }
          .select(&:many?)
      end
    end
end
