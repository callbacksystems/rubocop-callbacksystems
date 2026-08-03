# Keeps system tests on a real browser driver. `rack_test` skips JavaScript entirely, so a Hotwire application under it
# exercises pages that never behave like production. Integration tests already cover the fast no-browser path.
#
# @example
#   # bad - system tests without a browser
#   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
#     driven_by :rack_test
#   end
#
#   # good - headless browser
#   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
#     driven_by :selenium, using: :headless_chrome
#   end
#
class RuboCop::Cop::Callbacksystems::SystemTestBrowserDriver < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "System tests must drive a real browser. Replace `:rack_test` with `:selenium, using: :headless_chrome`."

  def on_send(node)
    add_offense(node, message: MESSAGE) if rack_test_driver?(node)
  end
  alias on_csend on_send

  private
    def rack_test_driver?(node)
      node.method?(:driven_by) && node.receiver.nil? &&
        node.first_argument&.sym_type? && node.first_argument.value == :rack_test
    end
end
