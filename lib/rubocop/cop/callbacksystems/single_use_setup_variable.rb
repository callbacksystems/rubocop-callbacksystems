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
    each_offense { |node, message| add_offense(node, message: message) }
  end

  private
    def each_offense(&block)
      if block
        yield_offenses(&block) if investigable?
      else
        to_enum(__method__)
      end
    end

    def investigable?
      processed_source.ast && !abstract_test_class?
    end

    def abstract_test_class?
      top_level_class = processed_source.ast.each_node(:class).first
      top_level_class && abstract_base_class?(top_level_class)
    end

    def abstract_base_class?(class_node)
      rails_test_base_class?(class_node.parent_class) && test_blocks(class_node).empty?
    end

    def yield_offenses(&block)
      tests = test_blocks
      setup_assignments.each do |assignment|
        message = offense_message_for(assignment, tests)
        yield assignment, message if message
      end
    end

    def setup_assignments
      setup_blocks.filter_map(&:body).flat_map { it.each_node(:ivasgn).to_a }
    end

    def offense_message_for(assignment, tests)
      case IvarUsage.new(processed_source.ast, assignment.name, tests).classify
      when :unused then format(UNUSED_MESSAGE, variable: assignment.name)
      when :single_use then format(USED_ONCE_MESSAGE, variable: assignment.name)
      end
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
          variable_references.any? { !inside_test_block?(it) }
        end

        def variable_references
          ast.each_node(:ivar).select { it.name == variable_name }
        end

        def inside_test_block?(ivar_node)
          test_blocks.any? { it.source_range.contains?(ivar_node.source_range) }
        end

        def tests_using_variable
          test_blocks.count do |test_block|
            test_block.each_node(:ivar).any? { it.name == variable_name }
          end
        end
    end
end
