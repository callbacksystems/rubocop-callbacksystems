# Requires parentheses on builder method calls (`.new`, ActiveRecord persistence, finders, strong parameters) when they
# have arguments. Bang methods and backslash continuations are exempt.
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

  MESSAGE = "Use parentheses for `%<method>s` when passing arguments."

  METHODS = %i[
    new
    create build update
    assign_attributes update_attribute update_column update_columns
    find find_by find_sole_by
    find_or_create_by find_or_initialize_by create_or_find_by
    destroy_by delete_by
    permit expect
  ].to_set.freeze

  def on_send(node)
    return if METHODS.exclude?(node.method_name)

    call = BuilderCall.new(node)
    add_offense(node, message: format(MESSAGE, method: node.method_name)) { call.parenthesize(it) } if call.missing_parentheses?
  end

  alias on_csend on_send

  private
    class BuilderCall
      def initialize(node)
        @node = node
      end

      def missing_parentheses?
        node.arguments? && !node.parenthesized? && !backslash_continuation?
      end

      def parenthesize(corrector)
        corrector.replace(gap_range, "(")
        corrector.insert_after(node.last_argument, ")")
      end

      private
        attr_reader :node

        def backslash_continuation?
          gap_range.source.include?("\\")
        end

        def gap_range
          Parser::Source::Range.new(node.source_range.source_buffer, node.loc.selector.end_pos, node.first_argument.source_range.begin_pos)
        end
    end
end
