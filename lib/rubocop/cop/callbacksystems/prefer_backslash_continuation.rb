# Prefers backslash line continuation over parentheses for multiline method calls.
# Single-line calls may use parentheses for constructors.
#
# @example
#   # bad - multiline with parentheses
#   claim = Account::Invitation::Claim.new(
#     invitation: invitations(:bruno),
#     name: "Test User"
#   )
#
#   # good - multiline with backslash
#   claim = Account::Invitation::Claim.new \
#     invitation: invitations(:bruno),
#     name: "Test User"
#
#   # good - single-line constructor
#   user = User.new(name: "Bruno")
#
#   # good - method call without parentheses
#   redirect_to account_path, notice: t(".success")
#
#   # good - nested call (can't use backslash inside another call)
#   update!(time_block: Model.find_or_create_by!(
#     starts_at: starts_at, ends_at: ends_at
#   ))
#
#   # good - block disambiguation (without parens block goes to outer method)
#   concat(tag.div do
#     content
#   end)
#
class RuboCop::Cop::Callbacksystems::PreferBackslashContinuation < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Use `\\` for line continuation instead of wrapping arguments in parentheses."

  def on_send(node)
    add_offense(node.loc.begin, message: MESSAGE) if MethodCall.new(node).offense?
  end

  alias on_csend on_send

  private
    class MethodCall
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        node.parenthesized? && multiline_send?(node) && !allowed?
      end

      private
        def allowed?
          nested_in_call? || argument_has_block? || contains_multiline_call? || inside_backslash_continuation? || chained_method_receiver? || inside_collection_literal?
        end

        def multiline_send?(send_node)
          send_node.arguments? && send_node.loc.begin && send_node.loc.end && send_node.loc.begin.line != send_node.loc.end.line
        end

        def nested_in_call?
          node.each_ancestor(:send).any? do |ancestor|
            ancestor.arguments.any? { it == node || it.each_descendant.include?(node) }
          end
        end

        def argument_has_block?
          direct_block_argument? || nested_block_in_arguments?
        end

        def direct_block_argument?
          node.arguments.any? { block_or_send_with_block?(it) }
        end

        def block_or_send_with_block?(arg)
          any_block_type?(arg) || (arg.send_type? && arg.parent&.block_type?)
        end

        def nested_block_in_arguments?
          node.arguments.flat_map { it.each_descendant(:any_block).to_a }.any?
        end

        def contains_multiline_call?
          node.each_descendant(:send).any? { multiline_send?(it) }
        end

        def inside_backslash_continuation?
          line_number = node.loc.begin.line - 1
          line_number.positive? && node.source_range.source_buffer.source.lines[line_number - 1]&.rstrip&.end_with?("\\")
        end

        def chained_method_receiver?
          node.parent&.call_type? && node.parent.receiver == node
        end

        def inside_collection_literal?
          node.each_ancestor(:hash, :array).any?
        end
    end
end
