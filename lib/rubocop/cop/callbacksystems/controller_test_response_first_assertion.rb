# In controller tests, the first assertion after an HTTP request must be a
# response assertion (assert_response or assert_redirected_to). The response is
# what the request produced, so it is read first: when the controller fails, a
# side-effect assertion placed before it fails on a symptom (a missing record)
# and hides the status that explains it. Non-assertion code between the request
# and the response assertion is allowed, and so are ActiveJob and ActionMailer
# assertions (assert_enqueued_jobs, assert_enqueued_emails, etc.).
#
# @example
#   # bad - first assertion is not about the response
#   test "create" do
#     post users_url, params: { name: "John" }
#     assert_equal 1, User.count
#     assert_response :created
#   end
#
#   # good - response assertion comes first
#   test "create" do
#     post users_url, params: { name: "John" }
#     assert_response :created
#     assert_equal 1, User.count
#   end
#
#   # good - non-assertion code before response assertion is fine
#   test "create" do
#     post users_url, params: { name: "John" }
#     user = User.last
#     assert_response :created
#     assert_equal "John", user.name
#   end
#
#   # good - assert_difference wrapping request, then response assertion
#   test "create" do
#     assert_difference("User.count", 1) do
#       post users_url, params: { name: "John" }
#     end
#     assert_response :created
#   end
#
#   # good - ActiveJob/ActionMailer assertions before response assertion
#   test "create sends email" do
#     post users_url, params: { name: "John" }
#     assert_enqueued_emails 1
#     assert_response :created
#   end
#
class RuboCop::Cop::Callbacksystems::ControllerTestResponseFirstAssertion < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::Testing::CopHelpers

  def on_block(node)
    report_each RequestAssertions.new(node) if test_block?(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    SIDE_EFFECT_ASSERTIONS = %i[
      assert_enqueued_jobs assert_no_enqueued_jobs assert_performed_jobs assert_no_performed_jobs
      assert_enqueued_with assert_performed_with
      assert_emails assert_no_emails assert_enqueued_emails assert_no_enqueued_emails assert_enqueued_email_with
    ]

    # The assertions a test reads first after each of its requests, kept when one is not about the response.
    class RequestAssertions
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Testing::CopHelpers
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "The first assertion after an HTTP request must be `assert_response` or `assert_redirected_to`, not " \
        "`%<method>s`."

      def initialize(node)
        @node = node
      end

      def each_offense
        misplaced_assertions.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :node

        def misplaced_assertions
          waiting_for_assertion = false
          statements.filter_map do |statement|
            if http_request_statement?(statement)
              waiting_for_assertion = true
              nil
            elsif waiting_for_assertion
              first_assertion_in(statement)&.then do |assertion|
                waiting_for_assertion = false
                assertion unless response_assertion?(assertion)
              end
            end
          end
        end

        def statements
          @statements ||= statements_in(node.body)
        end

        def http_request_statement?(statement)
          immediate_calls_in(statement).any? { http_request?(it) }
        end

        def first_assertion_in(statement)
          immediate_calls_in(statement).find { assertion?(it) && !side_effect_assertion?(it) }
        end

        def assertion?(send_node)
          call_on_self?(send_node) && send_node.method_name.to_s.start_with?("assert", "refute")
        end

        def side_effect_assertion?(send_node)
          call_on_self?(send_node) && SIDE_EFFECT_ASSERTIONS.include?(send_node.method_name)
        end

        def message_for(assertion)
          format(MESSAGE, method: assertion.method_name)
        end
    end
end
