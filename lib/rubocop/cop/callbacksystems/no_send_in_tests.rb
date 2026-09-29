# Prohibits using `send` or `__send__` inside test blocks.
# Private methods are private for a reason; tests should verify
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
  include RuboCop::Callbacksystems::Testing::CopHelpers

  def on_block(node)
    report_each RestrictedCalls.new(node) if test_block?(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class RestrictedCalls
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Don't use `%<method>s` to test private methods. Test behavior through the public interface instead."
      RESTRICTED_METHODS = %i[ send __send__ ]

      def initialize(test_block)
        @test_block = test_block
      end

      def each_offense
        restricted_calls.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :test_block

        def restricted_calls
          immediate_execution.select { restricted?(it) }
        end

        def immediate_execution
          RuboCop::Callbacksystems::Execution::Immediate.new(test_block.body, deferred_blocks: deferred_blocks)
        end

        def deferred_blocks
          nodes_in(test_block.body, :any_block).select { method_definition_block?(it) || nested_test_block?(it) }
        end

        def nested_test_block?(node)
          any_block_type?(node) && bare_send?(call_of(node)) && call_of(node).method?(:test)
        end

        def restricted?(send_node)
          send_node.call_type? && RESTRICTED_METHODS.include?(send_node.method_name) && !send_node.receiver.nil?
        end

        def message_for(send_node)
          format(MESSAGE, method: send_node.method_name)
        end
    end
end
