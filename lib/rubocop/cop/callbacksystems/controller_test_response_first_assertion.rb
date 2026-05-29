# In controller tests, the first assertion after an HTTP request must be a
# response assertion (assert_response or assert_redirected_to). Non-assertion
# code between the request and the response assertion is allowed.
# ActiveJob and ActionMailer assertions (assert_enqueued_jobs, assert_enqueued_emails,
# etc.) are also allowed before the response assertion.
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
  include RuboCop::Callbacksystems::TestCopHelpers

  MESSAGE = "The first assertion after an HTTP request must be `assert_response` or `assert_redirected_to`, not `%<method>s`."
  SIDE_EFFECT_ASSERTIONS = %i[
    assert_enqueued_jobs assert_no_enqueued_jobs assert_performed_jobs assert_no_performed_jobs
    assert_enqueued_with assert_performed_with
    assert_emails assert_no_emails assert_enqueued_emails assert_no_enqueued_emails assert_enqueued_email_with
  ].freeze

  def on_block(node)
    if test_block?(node)
      each_offense(node) { |offense_node, message| add_offense(offense_node, message: message) }
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def each_offense(node, &block)
      if block
        FirstAssertion.new(node).each_offense { yield it, format(MESSAGE, method: it.method_name) }
      else
        to_enum(__method__, node)
      end
    end

    class FirstAssertion
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::TestCopHelpers
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def each_offense
        statements.each_index.filter_map { offense_at(it) }.each { yield it }
      end

      private
        attr_reader :node

        def statements
          @statements ||= statements_in(node.body)
        end

        def offense_at(index)
          if http_request_statement?(statements[index])
            first = statements[(index + 1)..].find { assertion?(it) && !side_effect_assertion?(it) }
            first if first && !response_assertion?(first)
          end
        end

        def http_request_statement?(statement)
          (statement.send_type? && http_request?(statement)) || contains_http_request_in_block?(statement)
        end

        def contains_http_request_in_block?(statement)
          any_block_type?(statement) && statement.body&.each_node(:send)&.any? { http_request?(it) }
        end

        def assertion?(statement)
          bare_send?(statement) && statement.method_name.to_s.start_with?("assert", "refute")
        end

        def side_effect_assertion?(statement)
          bare_send?(statement) && SIDE_EFFECT_ASSERTIONS.include?(statement.method_name)
        end
    end
end
