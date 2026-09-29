# A long comment block is prose doing work the code should do. Inside a class
# body, two lines are enough for the non-obvious why. A block sitting
# immediately above a top-level class or module sometimes holds two of those
# whys, so it gets four. A block inside a `test` block narrates the scenario,
# so it has no limit there. Shortening prose is human judgment, so there is no
# autocorrection.
#
# @example
#   # bad - a three-line block inside a class body
#   class Widget
#     # The cache is warmed by the nightly job, and a miss here
#     # means the job never ran, so we raise instead of recomputing
#     # to surface the broken schedule.
#     def price
#     end
#   end
#
#   # good - two lines say the non-obvious why
#   class Widget
#     # A cache miss means the nightly job never ran, so we raise
#     # to surface the broken schedule instead of recomputing.
#     def price
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::CommentBlockLength < RuboCop::Cop::Callbacksystems::Base
  def on_new_investigation
    @comment_context = CommentContext.new(processed_source.ast)
    comment_blocks_in(processed_source).each { report measured_block_of(it) }
  end

  private
    attr_reader :comment_context

    def measured_block_of(comments)
      MeasuredBlock.new(comments, comment_context, max: cop_config["Max"], header_max: cop_config["HeaderMax"])
    end

    class MeasuredBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "This comment block spans %d lines where %d is the limit. Keep the non-obvious why and drop any " \
        "narration of the what."

      def initialize(comments, context, max:, header_max:)
        @comments = comments
        @context = context
        @max = max
        @header_max = header_max
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(range, message) if comments.size > limit && !inside_test?(range)
      end

      private
        attr_reader :comments, :context, :max, :header_max
        delegate :inside_test?, to: :context, private: true

        def limit
          top_level_header? ? header_max : max
        end

        def top_level_header?
          context.top_level_header_on?(comments.last.source_range.line)
        end

        def range
          range_spanning(comments)
        end

        def message
          format(MESSAGE, comments.size, limit)
        end
    end

    # File-wide comment contexts indexed once for all blocks in the investigation.
    class CommentContext
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Testing::CopHelpers
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast)
        @ast = ast
      end

      def top_level_header_on?(line)
        top_level_header_lines.include?(line)
      end

      def inside_test?(range)
        test_ranges.include?(range)
      end

      private
        attr_reader :ast

        def top_level_header_lines
          @top_level_header_lines ||= nodes_in(ast, :class, :module).filter_map do |node|
            node.first_line.pred if enclosing_class_or_module_of(node).nil?
          end.to_set
        end

        def test_ranges
          @test_ranges ||= ContainingRanges.new(test_blocks(ast).map(&:source_range))
        end

        # Source ranges supporting containment queries in logarithmic time, including nested ranges.
        class ContainingRanges
          def initialize(ranges)
            @ranges = ranges.sort_by(&:begin_pos)
          end

          def include?(range)
            candidate = first_range_after(range.begin_pos).pred
            candidate >= 0 && maximum_end_positions[candidate] >= range.end_pos
          end

          private
            attr_reader :ranges

            def first_range_after(position)
              begin_positions.bsearch_index { it > position } || ranges.size
            end

            def begin_positions
              @begin_positions ||= ranges.map(&:begin_pos)
            end

            def maximum_end_positions
              @maximum_end_positions ||= ranges.each_with_object([]) do |range, positions|
                positions << [ positions.last || 0, range.end_pos ].max
              end
            end
        end
    end
end
