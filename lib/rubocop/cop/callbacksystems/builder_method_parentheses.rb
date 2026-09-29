# Requires parentheses on builder method calls (`.new`, ActiveRecord persistence,
# finders, strong parameters) when they have arguments. A call that builds or
# looks up a record is an expression handing back a value, and the parentheses
# mark it as one, while a bare call reads as a declaration the way a macro does
# (`validates :name`). Bang methods and backslash continuations are exempt.
#
# @example
#   # bad
#   User.new name: "John"
#   User.create name: "John", email: "j@example.com"
#   User.find_by name: "John"
#   params.permit :name, :email
#
#   # good
#   User.new(name: "John")
#   User.create(name: "John", email: "j@example.com")
#   User.find_by(name: "John")
#   params.permit(:name, :email)
#
#   # good - bang methods exempt
#   User.create! name: "John"
#
#   # good - backslash continuation
#   User.create \
#     name: "John"
#
class RuboCop::Cop::Callbacksystems::BuilderMethodParentheses < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report BuilderCall.new(node) if builder_method?(node)
  end

  alias on_csend on_send

  private
    class BuilderCall
      MESSAGE = "Use parentheses for `%<method>s` when passing arguments."

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) { correct(it) } if missing_parentheses?
      end

      private
        attr_reader :node

        def missing_parentheses?
          node.arguments? && !node.parenthesized? && !backslash_continuation?
        end

        def backslash_continuation?
          gap_range.source.include?("\\")
        end

        def gap_range
          Parser::Source::Range.new \
            node.source_range.source_buffer, node.loc.selector.end_pos,
            node.first_argument.source_range.begin_pos
        end

        def message
          format(MESSAGE, method: node.method_name)
        end

        def correct(corrector)
          corrector.replace(gap_range, "(")
          corrector.insert_after(node.last_argument, ")")
        end
    end
end
