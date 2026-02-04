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
class RuboCop::Cop::Callbacksystems::PreferBackslashContinuation < RuboCop::Cop::Base
  MESSAGE = "Use `\\` for line continuation instead of wrapping arguments in parentheses."

  def on_send(node)
    add_offense(node.loc.begin, message: MESSAGE) if MethodCall.new(node).offense?
  end

  private
    class MethodCall
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        node.parenthesized? && multiline_call? && !block_call? && !nested_in_call? && !argument_has_block? && !contains_multiline_call? && !inside_backslash_continuation?
      end

      private
        def multiline_call?
          node.arguments? && node.loc.begin && node.loc.end && node.loc.begin.line != node.loc.end.line
        end

        def block_call?
          node.parent&.block_type? || node.parent&.numblock_type?
        end

        def nested_in_call?
          node.each_ancestor(:send).any? do |ancestor|
            ancestor.arguments.any? { |arg| arg == node || arg.each_descendant.include?(node) }
          end
        end

        def argument_has_block?
          direct_block_argument? || nested_block_in_arguments?
        end

        def direct_block_argument?
          node.arguments.any? { |arg| block_or_send_with_block?(arg) }
        end

        def block_or_send_with_block?(arg)
          arg.block_type? || arg.numblock_type? || (arg.send_type? && arg.parent&.block_type?)
        end

        def nested_block_in_arguments?
          node.arguments.flat_map { |arg| arg.each_descendant(:block, :numblock).to_a }.any?
        end

        def contains_multiline_call?
          node.each_descendant(:send).any? { |descendant| descendant_multiline?(descendant) }
        end

        def descendant_multiline?(descendant)
          descendant.arguments? && descendant.loc.begin && descendant.loc.end && descendant.loc.begin.line != descendant.loc.end.line
        end

        def inside_backslash_continuation?
          source = node.source_range.source_buffer.source
          line_number = node.loc.begin.line - 1
          line_number.positive? && source.lines[line_number - 1]&.rstrip&.end_with?("\\")
        end
    end
end
