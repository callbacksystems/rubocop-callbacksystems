# Prohibits using `send` or `__send__` inside test blocks. Private methods are private for a reason; tests should verify
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
class RuboCop::Cop::Callbacksystems::NoSendInTests < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers

  MESSAGE = "Don't use `%<method>s` to test private methods. Test behavior through the public interface instead."

  RESTRICTED_METHODS = %i[send __send__].freeze

  def on_block(node)
    if test_block?(node)
      each_offense(node) { |send_node, message| add_offense(send_node, message: message) }
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def each_offense(test_block, &block)
      if block
        test_block.body&.each_node(:send) do |send_node|
          next unless restricted_call?(send_node)

          yield send_node, format(MESSAGE, method: send_node.method_name)
        end
      else
        to_enum(__method__, test_block)
      end
    end

    def restricted_call?(send_node)
      RESTRICTED_METHODS.include?(send_node.method_name) && send_node.receiver
    end
end
