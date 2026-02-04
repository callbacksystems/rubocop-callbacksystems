require "test_helper"

class RuboCop::Cop::Callbacksystems::RestrictedControllerActionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RestrictedControllerActions

  test "allows standard index action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
        end
      end
    RUBY
  end

  test "allows standard show action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def show
        end
      end
    RUBY
  end

  test "allows standard new action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def new
        end
      end
    RUBY
  end

  test "allows standard create action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def create
        end
      end
    RUBY
  end

  test "allows standard edit action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def edit
        end
      end
    RUBY
  end

  test "allows standard update action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def update
        end
      end
    RUBY
  end

  test "allows standard destroy action" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def destroy
        end
      end
    RUBY
  end

  test "registers offense for custom public action" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def activate
        end
      end
    RUBY
  end

  test "allows private methods" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
        end

        private

        def set_user
        end

        def user_params
        end
      end
    RUBY
  end

  test "allows protected methods" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
        end

        protected

        def authorize_user
        end
      end
    RUBY
  end

  test "does not apply to non-controller files" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        def activate
        end
      end
    RUBY
  end

  test "applies to files in controllers directory" do
    assert_offense <<~RUBY, file: "app/controllers/admin/users_controller.rb"
      class Admin::UsersController < ApplicationController
        def activate
        end
      end
    RUBY
  end

  test "allows any methods in modules (concerns)" do
    assert_no_offense <<~RUBY, file: "app/controllers/concerns/authentication.rb"
      module Authentication
        def current_user
        end

        def authenticate!
        end
      end
    RUBY
  end

  test "allows any methods in concerns with extend ActiveSupport::Concern" do
    assert_no_offense <<~RUBY, file: "app/controllers/concerns/trackable.rb"
      module Trackable
        extend ActiveSupport::Concern

        def track_event
        end
      end
    RUBY
  end

  test "applies to classes inheriting from custom base controller" do
    assert_offense <<~RUBY, file: "app/controllers/admin/users_controller.rb"
      class Admin::UsersController < Admin::BaseController
        def activate
        end
      end
    RUBY
  end

  test "applies to classes inheriting from ActionController::Base" do
    assert_offense <<~RUBY, file: "app/controllers/application_controller.rb"
      class ApplicationController < ActionController::Base
        def custom_action
        end
      end
    RUBY
  end

  test "applies to classes inheriting from ActionController::API" do
    assert_offense <<~RUBY, file: "app/controllers/api/base_controller.rb"
      class Api::BaseController < ActionController::API
        def custom_action
        end
      end
    RUBY
  end

  test "does not apply to classes without superclass" do
    assert_no_offense <<~RUBY, file: "app/controllers/some_class.rb"
      class SomeClass
        def custom_action
        end
      end
    RUBY
  end
end
