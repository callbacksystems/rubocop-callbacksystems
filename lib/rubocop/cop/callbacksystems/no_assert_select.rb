# Prohibits using assert_select in tests.
#
# Testing HTML content couples tests to markup implementation details.
# Tests should verify behavior through response status, redirects, and
# data changes, not by inspecting HTML structure.
#
# @example
#   # bad - testing HTML content
#   assert_select "div.notice", text: /Welcome/
#   assert_select "h1", "Dashboard"
#   assert_select "input[type=email]"
#
#   # good - test response and behavior
#   assert_response :success
#   assert_redirected_to dashboard_path
#   assert user.confirmed?
#
class RuboCop::Cop::Callbacksystems::NoAssertSelect < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Don't use `assert_select` to test HTML content. Test response status, redirects, and data changes instead."

  # @!method assert_select_call?(node)
  def_node_matcher :assert_select_call?, <<~PATTERN
    (send nil? :assert_select ...)
  PATTERN

  def on_send(node)
    add_offense(node, message: MESSAGE) if assert_select_call?(node)
  end

  alias on_csend on_send
end
