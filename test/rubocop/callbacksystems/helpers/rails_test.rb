require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::RailsTest < HelpersTestCase
  test "controller_superclass? matches ApplicationController" do
    superclass = parse("ApplicationController").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches ActionController::Base" do
    superclass = parse("ActionController::Base").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches any namespaced *Controller" do
    superclass = parse("Admin::UsersController").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? does not match unrelated constants" do
    superclass = parse("ActiveRecord::Base").ast

    assert_not Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? returns falsy for nil" do
    assert_not Helpers.controller_superclass?(nil)
  end

  test "rails_test_base_class? matches ActiveSupport::TestCase" do
    superclass = parse("ActiveSupport::TestCase").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? matches ActionDispatch::IntegrationTest" do
    superclass = parse("ActionDispatch::IntegrationTest").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? does not match unrelated classes" do
    superclass = parse("ApplicationController").ast

    assert_not Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? does not match subclasses of test bases" do
    superclass = parse("ActionDispatch::SystemTestCase").ast

    assert_not Helpers.rails_test_base_class?(superclass)
  end
end
