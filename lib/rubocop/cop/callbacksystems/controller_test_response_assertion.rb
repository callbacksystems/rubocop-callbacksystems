# In controller tests, every test that makes an HTTP request must assert the response.
# Testing only side effects without verifying the response status or redirect
# leaves the controller's behavior unverified.
#
# @example
#   # bad - no response assertion
#   test "create creates a user" do
#     post users_url, params: { name: "John" }
#     assert_equal 1, User.count
#   end
#
#   # good - asserts response status
#   test "create creates a user" do
#     post users_url, params: { name: "John" }
#     assert_response :created
#     assert_equal 1, User.count
#   end
#
#   # good - asserts redirect
#   test "create redirects" do
#     post users_url, params: { name: "John" }
#     assert_redirected_to users_path
#   end
#
#   # good - no HTTP request (not a controller action test)
#   test "helper works" do
#     assert_equal "expected", helper_method
#   end
#
class RuboCop::Cop::Callbacksystems::ControllerTestResponseAssertion < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers

  MESSAGE = "Controller test makes an HTTP request but has no response assertion (assert_response or assert_redirected_to)."
  # If a test asserts an exception, the request didn't complete normally,
  # so checking the response status is unnecessary.
  EXTRA_RESPONSE_ASSERTIONS = %i[assert_raises].freeze

  def on_block(node)
    return unless test_block?(node)

    add_offense(node, message: MESSAGE) if body_has_http_request?(node) && !body_has_response_assertion?(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def body_has_response_assertion?(node)
      node.body&.each_node(:send)&.any? do |send_node|
        response_assertion?(send_node) || extra_response_assertion?(send_node)
      end
    end

    def extra_response_assertion?(send_node)
      send_node.receiver.nil? && EXTRA_RESPONSE_ASSERTIONS.include?(send_node.method_name)
    end
end
