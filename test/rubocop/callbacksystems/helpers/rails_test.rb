require "test_helper"

class RuboCop::Callbacksystems::Helpers::RailsTest < HelpersTestCase
  test "controller_class? returns true for a class inheriting from a controller" do
    assert Helpers.controller_class?(processed_source("class UsersController < ApplicationController; end").ast)
  end

  test "controller_class? returns false for other classes, modules, and nil" do
    assert_not Helpers.controller_class?(processed_source("class User < ApplicationRecord; end").ast)
    assert_not Helpers.controller_class?(processed_source("module Admin; end").ast)
    assert_not Helpers.controller_class?(nil)
  end

  test "controller_superclass? matches ApplicationController" do
    superclass = processed_source("ApplicationController").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches ActionController::Base" do
    superclass = processed_source("ActionController::Base").ast

    assert Helpers.controller_superclass?(superclass)
  end

  test "controller_superclass? matches an explicitly top-level controller base" do
    superclass = processed_source("::ActionController::Base").ast

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

  test "application_controller_class? matches only classes named ApplicationController" do
    assert Helpers.application_controller_class?(processed_source("class ApplicationController; end").ast)
    assert Helpers.application_controller_class?(processed_source("class Admin::ApplicationController; end").ast)
    assert_not Helpers.application_controller_class?(processed_source("class UsersController; end").ast)
    assert_not Helpers.application_controller_class?(processed_source("module ApplicationController; end").ast)
    assert_not Helpers.application_controller_class?(nil)
  end

  test "scope_definition? returns true for a bare scope naming a symbol" do
    assert Helpers.scope_definition?(processed_source("scope :active, -> { where(active: true) }").ast)
  end

  test "scope_definition? returns false for a scope with a receiver, another macro, or no symbol" do
    assert_not Helpers.scope_definition?(processed_source("other.scope :active").ast)
    assert_not Helpers.scope_definition?(processed_source("validates :active").ast)
    assert_not Helpers.scope_definition?(processed_source("scope \"active\"").ast)
    assert_not Helpers.scope_definition?(processed_source("scope").ast)
  end

  test "rails_test_base_class? matches ActiveSupport::TestCase" do
    superclass = processed_source("ActiveSupport::TestCase").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? matches ActionDispatch::IntegrationTest" do
    superclass = processed_source("ActionDispatch::IntegrationTest").ast

    assert Helpers.rails_test_base_class?(superclass)
  end

  test "rails_test_base_class? matches an explicitly top-level test base" do
    superclass = processed_source("::ActiveSupport::TestCase").ast

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

  test "controller_file? matches a file under controllers or named as one" do
    assert Helpers.controller_file?("app/controllers/orders_controller.rb")
    assert Helpers.controller_file?("lib/admin/orders_controller.rb")
    assert Helpers.controller_file?("app/controllers/concerns/authentication.rb")
  end

  test "controller_file? rejects other paths and a missing one" do
    assert_not Helpers.controller_file?("app/models/order.rb")
    assert_not Helpers.controller_file?(nil)
  end

  test "model_file? recognizes models and concerns in apps and engines" do
    assert Helpers.model_file?("app/models/order.rb")
    assert Helpers.model_file?("/project/app/models/concerns/searchable.rb")
    assert Helpers.model_file?("engines/admin/app/models/order.rb")
    assert Helpers.model_file?("C:\\project\\app\\models\\order.rb")
  end

  test "model_file? rejects similarly named paths and a missing one" do
    assert_not Helpers.model_file?("lib/app_models/order.rb")
    assert_not Helpers.model_file?("app/models_archive/order.rb")
    assert_not Helpers.model_file?("test/models/order_test.rb")
    assert_not Helpers.model_file?(nil)
  end

  test "test_file? matches a file named as a test" do
    assert Helpers.test_file?("test/models/order_test.rb")
    assert_not Helpers.test_file?("app/models/order.rb")
    assert_not Helpers.test_file?(nil)
  end
end
