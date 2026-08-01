require "test_helper"

class RuboCop::Cop::Callbacksystems::SystemTestBrowserDriverTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SystemTestBrowserDriver

  test "registers offense for rack_test driver" do
    assert_offense <<~RUBY, file: "test/application_system_test_case.rb"
      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :rack_test
      end
    RUBY
  end

  test "registers offense for rack_test driver with extra options" do
    assert_offense <<~RUBY, file: "test/application_system_test_case.rb"
      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :rack_test, screen_size: [1400, 1400]
      end
    RUBY
  end

  test "registers offense for rack_test in an individual system test" do
    assert_offense <<~RUBY, file: "test/system/messages_test.rb"
      class MessagesTest < ApplicationSystemTestCase
        driven_by :rack_test
      end
    RUBY
  end

  test "allows selenium driver" do
    assert_no_offense <<~RUBY, file: "test/application_system_test_case.rb"
      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :selenium, using: :headless_chrome
      end
    RUBY
  end

  test "allows selenium with other browsers" do
    assert_no_offense <<~RUBY, file: "test/application_system_test_case.rb"
      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :selenium, using: :headless_firefox
      end
    RUBY
  end

  test "allows driven_by with a receiver" do
    assert_no_offense <<~RUBY, file: "test/application_system_test_case.rb"
      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        Capybara.driven_by :rack_test
      end
    RUBY
  end
end
