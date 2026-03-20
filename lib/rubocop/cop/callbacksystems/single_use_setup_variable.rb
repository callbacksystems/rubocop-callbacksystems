# Detects instance variables assigned in setup blocks that are only used in a single test.
# Such variables should be inlined into the test where they are used.
#
# @example
#   # bad - @order is only used in one test
#   setup do
#     @order = orders(:one)
#   end
#
#   test "order is valid" do
#     assert @order.valid?
#   end
#
#   test "something else" do
#     assert true
#   end
#
#   # good - variable used in multiple tests
#   setup do
#     @order = orders(:one)
#   end
#
#   test "order is valid" do
#     assert @order.valid?
#   end
#
#   test "order has items" do
#     assert @order.items.any?
#   end
#
class RuboCop::Cop::Callbacksystems::SingleUseSetupVariable < RuboCop::Cop::Base
  MESSAGE = "Instance variable `%<variable>s` is only used in one test. Inline it instead of assigning in `setup`."

  def on_new_investigation
    return unless processed_source.ast

    setup_assignments.each do |assignment|
      variable_name = assignment.children.first
      test_count = tests_using_variable(variable_name)
      next unless test_count == 1

      add_offense(assignment, message: format(MESSAGE, variable: variable_name))
    end
  end

  private
    def setup_assignments
      setup_blocks.flat_map do |block|
        block.body ? block.body.each_node(:ivasgn).to_a : []
      end
    end

    def setup_blocks
      processed_source.ast.each_node(:block).select do |node|
        node.send_node.method_name == :setup && node.send_node.receiver.nil?
      end
    end

    def test_blocks
      @test_blocks ||= processed_source.ast.each_node(:block).select do |node|
        node.send_node.method_name == :test && node.send_node.receiver.nil?
      end
    end

    def tests_using_variable(variable_name)
      test_blocks.count do |test_block|
        test_block.each_node(:ivar).any? { |ivar| ivar.children.first == variable_name }
      end
    end
end
