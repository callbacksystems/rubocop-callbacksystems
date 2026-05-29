# A negative `return unless` guard followed by a happy path reads more naturally
# as `if cond; ...; end`. The wrap adds one `if` block, so it is only applied when
# the happy path's own nesting plus that extra level still fits inside RuboCop's
# `Metrics/BlockNesting` (3 by default); anything past that would push the method
# past the nesting limit. Method-length rules already cap how long a happy path
# can be, so the only real cost of the wrap is the indent level it adds.
#
# @example
#   # bad - leading negative guard
#   def label
#     return unless ready?
#     compute_label
#   end
#
#   # good - positive wrap
#   def label
#     if ready?
#       compute_label
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferPositiveWrap < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Wrap positively: `if cond; ...; end` instead of a leading negative guard."

  def on_def(node)
    wrap = WrappableGuard.new(node.body)
    add_offense(wrap.guard, message: MESSAGE) { wrap.correct(it) } if wrap.offense?
  end

  alias on_defs on_def

  private
    # The leading negative guard inside a method body, plus the happy path that
    # follows it. Owns the wrap construction so the cop only routes nodes.
    class WrappableGuard
      include RuboCop::Callbacksystems::Helpers

      MAX_TOTAL_DEPTH = 3
      NESTING_TYPES = %i[if case while until while_post until_post for rescue].to_set.freeze

      def initialize(body)
        @body = body
      end

      def offense?
        statements.size >= 2 && negative_return_guard?(guard) && happy_max_depth + 1 <= MAX_TOTAL_DEPTH
      end

      def guard
        statements.first
      end

      def correct(corrector)
        corrector.replace(guard.source_range.join(happy.last.source_range), wrapped_source)
      end

      private
        attr_reader :body

        def statements
          statements_in(body)
        end

        def negative_return_guard?(node)
          node&.if_type? && node.unless? && node.if_branch&.return_type?
        end

        def happy_max_depth
          happy.map { depth_of(it) }.max || 0
        end

        def happy
          statements.drop(1)
        end

        def depth_of(node)
          if countable?(node)
            child_max = node.each_child_node.map { depth_of(it) }.max || 0
            (NESTING_TYPES.include?(node.type) ? 1 : 0) + child_max
          else
            0
          end
        end

        def countable?(node)
          node.is_a?(RuboCop::AST::Node) && !node.def_type? && !node.defs_type?
        end

        def wrapped_source
          "if #{guard.condition.source}\n#{indented_happy}\n#{else_branch}#{indent}end"
        end

        def indented_happy
          lines = happy_source.split("\n")
          [ "#{indent}  #{lines.first}", *lines.drop(1).map { it.empty? ? it : "  #{it}" } ].join("\n")
        end

        def happy_source
          body.source_range.source_buffer.source[happy.first.source_range.begin_pos...happy.last.source_range.end_pos]
        end

        def indent
          " " * guard.loc.column
        end

        def else_branch
          guard_value ? "#{indent}else\n#{indent}  #{guard_value.source}\n" : ""
        end

        def guard_value
          guard.if_branch.children.first
        end
    end
end
