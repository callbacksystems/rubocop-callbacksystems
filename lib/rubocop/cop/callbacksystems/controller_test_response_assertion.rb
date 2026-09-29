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
  include RuboCop::Callbacksystems::Testing::CopHelpers

  def on_block(node)
    report_each RequestResponses.new(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    REQUEST_ABORTING_ASSERTIONS = %i[ assert_raises ]

    class RequestResponses
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Testing::CopHelpers
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Controller test makes an HTTP request but has no response assertion (assert_response or " \
        "assert_redirected_to)."

      def initialize(node)
        @node = node
      end

      def each_offense
        missing_requests.each { yield RuboCop::Callbacksystems::Offense.new(it, MESSAGE) }
      end

      private
        attr_reader :node

        def missing_requests
          if test_block?(node)
            request_runs.filter_map do |run|
              request = run.first
              request if request_statement?(request) && !request_answered_in?(run)
            end
          else
            []
          end
        end

        def request_runs
          statements.slice_before { request_statement?(it) }
        end

        def statements
          @statements ||= statements_in(node.body)
        end

        def request_statement?(statement)
          immediate_calls_in(statement).any? { http_request?(it) }
        end

        def request_answered_in?(run)
          run.any? { response_assertion_in?(it) } || request_aborted_in?(run.first)
        end

        def response_assertion_in?(statement)
          immediate_calls_in(statement).any? { response_assertion?(it) }
        end

        def request_aborted_in?(statement)
          immediate_calls_in(statement).select { http_request?(it) }.all? do |request|
            request.each_ancestor(:any_block)
              .take_while { it.equal?(statement) || statement.source_range.contains?(it.source_range) }
              .any? { request_aborting_assertion?(it.send_node) }
          end
        end

        def request_aborting_assertion?(send_node)
          call_on_self?(send_node) && REQUEST_ABORTING_ASSERTIONS.include?(send_node.method_name)
        end
    end
end
