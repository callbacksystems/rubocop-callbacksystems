# Enforces the use of `test "description" do` syntax instead of `def test_*`
# for test methods, and block syntax for setup/teardown instead of method definitions.
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
class RuboCop::Cop::Callbacksystems::TestMethodDefinition < RuboCop::Cop::Base
  TEST_MESSAGE = "Use `test \"description\" do` instead of `def %<method>s`."
  BLOCK_MESSAGE = "Use `%<method>s do` block instead of `def %<method>s`."

  def on_def(node)
    method_name = node.method_name.to_s

    message = if method_name.start_with?("test_")
      format(TEST_MESSAGE, method: method_name)
    elsif %w[setup teardown].include?(method_name)
      format(BLOCK_MESSAGE, method: method_name)
    end

    add_offense(node, message: message) if message
  end
end
