# Detects instance variables assigned in setup blocks that are used in at most one test.
# Such variables should be inlined into the test where they are used (or removed if unused).
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
#   # bad - @order is not used in any test
#   setup do
#     @order = orders(:one)
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
class RuboCop::Cop::Callbacksystems::SingleUseSetupVariable < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers

  USED_ONCE_MESSAGE = "Instance variable `%<variable>s` is only used in one test. Inline it instead of assigning in `setup`."
  UNUSED_MESSAGE = "Instance variable `%<variable>s` assigned in `setup` is not used by any test. Remove it."

  def on_new_investigation
    return unless investigable?

    test_blocks = collect_test_blocks
    setup_assignments.each do |assignment|
      offense_message_for(assignment, test_blocks).then { add_offense(assignment, message: it) if it }
    end
  end

  private
    def investigable?
      processed_source.ast && !abstract_test_class?
    end

    def abstract_test_class?
      top_level_class = processed_source.ast.each_node(:class).first
      top_level_class && abstract_base_class?(top_level_class)
    end

    def abstract_base_class?(class_node)
      rails_test_base_class?(class_node.parent_class) && tests_in(class_node).empty?
    end

    def tests_in(class_node)
      class_node.each_node(:block).select { test_block?(it) }
    end

    def offense_message_for(assignment, test_blocks)
      variable_name = assignment.children.first
      case IvarUsage.new(processed_source.ast, variable_name, test_blocks).classify
      when :unused then format(UNUSED_MESSAGE, variable: variable_name)
      when :single_use then format(USED_ONCE_MESSAGE, variable: variable_name)
      end
    end

    def setup_assignments
      collect_setup_blocks.flat_map do |block|
        block.body ? block.body.each_node(:ivasgn).to_a : []
      end
    end

    def collect_setup_blocks
      processed_source.ast.each_node(:block).select do |node|
        node.method?(:setup) && node.receiver.nil?
      end
    end

    def collect_test_blocks
      processed_source.ast.each_node(:block).select { test_block?(it) }
    end

    class IvarUsage
      def initialize(ast, variable_name, test_blocks)
        @ast = ast
        @variable_name = variable_name
        @test_blocks = test_blocks
      end

      def classify
        return :ok if used_outside_tests?

        case tests_using_variable
        when 0 then :unused
        when 1 then :single_use
        else :ok
        end
      end

      private
        attr_reader :ast, :variable_name, :test_blocks

        def used_outside_tests?
          references.any? { !inside_test_block?(it) }
        end

        def tests_using_variable
          test_blocks.count do |test_block|
            test_block.each_node(:ivar).any? { it.children.first == variable_name }
          end
        end

        def references
          ast.each_node(:ivar).select { it.children.first == variable_name }
        end

        def inside_test_block?(ivar_node)
          test_blocks.any? { it.source_range.contains?(ivar_node.source_range) }
        end
    end
end
