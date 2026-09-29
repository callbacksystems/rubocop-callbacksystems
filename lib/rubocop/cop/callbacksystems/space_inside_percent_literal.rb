# Requires a space inside the delimiters of a percent literal, the way an array
# literal carries one. `Layout/SpaceInsideArrayLiteralBrackets` asks for `[ a, b ]`
# and `Layout/SpaceInsideHashLiteralBraces` for `{ a: 1 }`, while the core cop for
# these literals can only forbid the space, so this one asks for it and that one
# stays off.
#
# A literal spanning several lines is left alone, since the line breaks already
# separate its elements, and so is an empty one, which has nothing to separate.
#
# @example
#   # bad
#   %i[save update]
#   %w[a b]
#
#   # good
#   %i[ save update ]
#   %w[ a b ]
#
#   # good - the line breaks separate these
#   %i[
#     save update
#     destroy
#   ]
#
#   # good - nothing to separate
#   %i[]
#
class RuboCop::Cop::Callbacksystems::SpaceInsidePercentLiteral < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_array(node)
    report PercentLiteral.new(node) if node.percent_literal?
  end

  private
    class PercentLiteral
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Add a space inside the delimiters, the way an array literal carries one."

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE) { correct(it) } if unspaced?
      end

      private
        attr_reader :node

        def unspaced?
          eligible? && [ opening_gap, closing_gap ].any? { it.source != " " }
        end

        def eligible?
          node.children.any? && same_line?(node.loc.begin, node.loc.end)
        end

        def opening_gap
          node.loc.begin.end.join(node.children.first.source_range.begin)
        end

        def closing_gap
          node.children.last.source_range.end.join(node.loc.end.begin)
        end

        def correct(corrector)
          corrector.replace(opening_gap, " ")
          corrector.replace(closing_gap, " ")
        end
    end
end
