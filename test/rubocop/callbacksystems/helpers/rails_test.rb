require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::RailsTest < HelpersTestCase
  test "controller_superclass? matches ApplicationController" do
    superclass = processed_source("ApplicationController").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches ActionController::Base" do
    superclass = processed_source("ActionController::Base").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches any namespaced *Controller" do
    superclass = processed_source("Admin::UsersController").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? does not match unrelated constants" do
    superclass = processed_source("ActiveRecord::Base").ast

    assert_not Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? returns falsy for nil" do
    assert_not Helpers.controller_superclass?(nil)
  end

  test "rails_test_base_class? matches ActiveSupport::TestCase" do
    superclass = processed_source("ActiveSupport::TestCase").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? matches ActionDispatch::IntegrationTest" do
    superclass = processed_source("ActionDispatch::IntegrationTest").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? does not match unrelated classes" do
    superclass = processed_source("ApplicationController").ast

    assert_not Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? does not match subclasses of test bases" do
    superclass = processed_source("ActionDispatch::SystemTestCase").ast

    assert_not Helpers.rails_test_base_class?(superclass)
  end

  test "routes_file? matches the main routes file" do
    assert Helpers.routes_file?("config/routes.rb")
  end

  test "routes_file? matches files under config/routes" do
    assert Helpers.routes_file?("config/routes/admin.rb")
  end

  test "routes_file? does not match unrelated files" do
    assert_not Helpers.routes_file?("app/models/user.rb")
  end

  test "routes_file? returns falsy for nil" do
    assert_not Helpers.routes_file?(nil)
  end
end
