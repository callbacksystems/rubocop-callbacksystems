# Asks for `test "description" do` over `def test_*`, and for `setup` and
# `teardown` blocks over methods of those names. A description in plain words
# says more than an underscored method name, and a `setup` block runs beside
# the ones a parent class declares, where a `setup` method replaces them unless
# it remembers to call `super`.
#
# @example
#   # bad
#   def test_something
#     assert true
#   end
#
#   # good
#   test "something" do
#     assert true
#   end
#
#   # bad
#   def setup
#     @user = users(:bruno)
#   end
#
#   # good
#   setup do
#     @user = users(:bruno)
#   end
#
#   # bad
#   def teardown
#     cleanup
#   end
#
#   # good
#   teardown do
#     cleanup
#   end
#
class RuboCop::Cop::Callbacksystems::TestMethodDefinition < RuboCop::Cop::Callbacksystems::Base
  TEST_MESSAGE = "Use `test \"description\" do` instead of `def %<method>s`."
  BLOCK_MESSAGE = "Use `%<method>s do` block instead of `def %<method>s`."

  def on_def(node)
    report MethodDefinition.new(node)
  end

  private
    class MethodDefinition
      include RuboCop::Callbacksystems::Helpers

      TEST_PREFIX = "test_"
      HOOK_METHODS = %i[ setup teardown ]

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if inside_test_class? && message
      end

      private
        attr_reader :node

        def inside_test_class?
          class_node = enclosing_class_or_module_of(node)
          direct_method_definition?(node) && class_node.class_type? && (class_name_of(class_node).end_with?("Test") ||
            rails_test_base_class?(class_node.parent_class))
        end

        def message
          if test_method?
            format(TEST_MESSAGE, method: node.method_name)
          elsif hook_method?
            format(BLOCK_MESSAGE, method: node.method_name)
          end
        end

        def test_method?
          node.method_name.start_with?(TEST_PREFIX)
        end

        def hook_method?
          HOOK_METHODS.include?(node.method_name)
        end
    end
end
