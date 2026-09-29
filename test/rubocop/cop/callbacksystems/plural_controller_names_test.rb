require "test_helper"

class RuboCop::Cop::Callbacksystems::PluralControllerNamesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PluralControllerNames

  test "registers offense for singular controller name" do
    assert_offense <<~RUBY, file: "app/controllers/user_controller.rb"
      class UserController < ApplicationController
      end
    RUBY
  end

  test "registers offense for singular nested controller" do
    assert_offense <<~RUBY, file: "app/controllers/admin/user_controller.rb"
      class Admin::UserController < ApplicationController
      end
    RUBY
  end

  test "allows plural controller name ending in -s" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
      end
    RUBY
  end

  test "allows plural controller name ending in -es" do
    assert_no_offense <<~RUBY, file: "app/controllers/boxes_controller.rb"
      class BoxesController < ApplicationController
      end
    RUBY
  end

  test "allows plural controller name ending in -ies" do
    assert_no_offense <<~RUBY, file: "app/controllers/categories_controller.rb"
      class CategoriesController < ApplicationController
      end
    RUBY
  end

  test "allows irregular plural People" do
    assert_no_offense <<~RUBY, file: "app/controllers/people_controller.rb"
      class PeopleController < ApplicationController
      end
    RUBY
  end

  test "registers offense for singular Person" do
    assert_offense <<~RUBY, file: "app/controllers/person_controller.rb"
      class PersonController < ApplicationController
      end
    RUBY
  end

  test "allows nested plural controllers" do
    assert_no_offense <<~RUBY, file: "app/controllers/admin/users_controller.rb"
      class Admin::UsersController < Admin::BaseController
      end
    RUBY
  end

  test "does not apply to non-controller classes" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
      end
    RUBY
  end

  test "applies to classes inheriting from ActionController::API" do
    assert_offense <<~RUBY, file: "app/controllers/api/user_controller.rb"
      class Api::UserController < ActionController::API
      end
    RUBY
  end

  test "allows ApplicationController (ignored by default)" do
    assert_no_offense <<~RUBY, file: "app/controllers/application_controller.rb"
      class ApplicationController < ActionController::Base
      end
    RUBY
  end

  test "allows BaseController (ignored by default)" do
    assert_no_offense <<~RUBY, file: "app/controllers/base_controller.rb"
      class BaseController < ApplicationController
      end
    RUBY
  end

  test "allows namespaced BaseController" do
    assert_no_offense <<~RUBY, file: "app/controllers/admin/base_controller.rb"
      class Admin::BaseController < ApplicationController
      end
    RUBY
  end

  test "allows Api::BaseController" do
    assert_no_offense <<~RUBY, file: "app/controllers/api/base_controller.rb"
      class Api::BaseController < ActionController::API
      end
    RUBY
  end
end
