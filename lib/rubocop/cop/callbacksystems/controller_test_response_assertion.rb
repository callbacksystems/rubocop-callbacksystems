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
class RuboCop::Cop::Callbacksystems::ControllerTestResponseAssertion < RuboCop::Cop::Base
  MESSAGE = "Controller test makes an HTTP request but has no response assertion (assert_response or assert_redirected_to)."
  HTTP_METHODS = %i[get post put patch delete].freeze
  RESPONSE_ASSERTIONS = %i[assert_response assert_redirected_to assert_raises].freeze

  # Matches: test "description" do ... end
  def_node_matcher :test_block?, <<~PATTERN
    (block (send nil? :test (str $_)) ...)
  PATTERN

  def on_block(node)
    return unless test_block?(node)

    add_offense(node, message: MESSAGE) if TestBlock.new(node).offense?
  end

  private
    class TestBlock
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        has_http_request? && !has_response_assertion?
      end

      private
        def has_http_request?
          node.body&.each_node(:send)&.any? { |send_node| http_request?(send_node) }
        end

        def has_response_assertion?
          node.body&.each_node(:send)&.any? { |send_node| response_assertion?(send_node) }
        end

        def http_request?(send_node)
          send_node.receiver.nil? && HTTP_METHODS.include?(send_node.method_name)
        end

        def response_assertion?(send_node)
          send_node.receiver.nil? && RESPONSE_ASSERTIONS.include?(send_node.method_name)
        end
    end
end
