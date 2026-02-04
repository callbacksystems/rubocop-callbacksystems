require "test_helper"

class RuboCop::Cop::Callbacksystems::RoutesModuleScopeTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RoutesModuleScope

  test "registers offense for repeated module option" do
    offenses = assert_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "registers offense for three repeated module options" do
    offenses = assert_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
        resources :comments, module: :admin
      end
    RUBY
    assert_equal 3, offenses.size
  end

  test "allows single module option" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts
      end
    RUBY
  end

  test "allows different module values" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :api
      end
    RUBY
  end

  test "allows scope block with module" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        scope module: :admin do
          resources :users
          resources :posts
        end
      end
    RUBY
  end

  test "does not apply to non-routes files" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
  end

  test "applies to files in config/routes directory" do
    offenses = assert_offense <<~RUBY, file: "config/routes/admin.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "handles get/post with module option" do
    offenses = assert_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "/dashboard", to: "dashboard#index", module: :admin
        post "/login", to: "sessions#create", module: :admin
      end
    RUBY
    assert_equal 2, offenses.size
  end
end
