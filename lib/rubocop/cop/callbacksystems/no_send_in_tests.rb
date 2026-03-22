# Prohibits using `send` or `__send__` inside test blocks.
# Private methods are private for a reason—tests should verify
# behavior and outcomes, not call private methods directly.
#
# @example
#   # bad
#   test "processes payment" do
#     result = order.send(:process_payment)
#     assert result
#   end
#
#   # bad
#   test "processes payment" do
#     order.__send__(:process_payment)
#   end
#
#   # good - test the public interface
#   test "processes payment" do
#     order.checkout
#     assert order.paid?
#   end
#
class RuboCop::Cop::Callbacksystems::NoSendInTests < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::TestCopHelpers

  MESSAGE = "Don't use `%<method>s` to test private methods. Test behavior through the public interface instead."

  RESTRICTED_METHODS = %i[send __send__].freeze

  def on_block(node)
    return unless test_block?(node)

    node.body&.each_node(:send) do |send_node|
      next if RESTRICTED_METHODS.exclude?(send_node.method_name)
      next if send_node.receiver.nil?

      add_offense(send_node, message: format(MESSAGE, method: send_node.method_name))
    end
  end
end
