require "test_helper"

class RuboCop::Cop::Callbacksystems::NoCustomRouteActionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoCustomRouteActions

  test "registers offense for member block" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        member do
          post :confirm
        end
      end
    RUBY
  end

  test "registers a member block inside resources using the implicit parameter" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        constrain(it)
        member do
          post :confirm
        end
      end
    RUBY
  end

  test "registers offense for collection block" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        collection do
          get :search
        end
      end
    RUBY
  end

  test "registers offense for new block" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        new do
          get :preview
        end
      end
    RUBY
  end

  test "registers offense for on member option" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        post :confirm, on: :member
      end
    RUBY
  end

  test "registers offense for on collection option" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :search, on: :collection
      end
    RUBY
  end

  test "registers offense for on new option" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, on: :new
      end
    RUBY
  end

  test "uses the last duplicate on option" do
    offenses = assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, on: :collection, on: :member
      end
    RUBY

    assert_includes offenses.first.message, "on: :member"
  end

  test "allows an on option that a following keyword splat can replace" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, on: :member, **route_options
      end
    RUBY
  end

  test "registers an explicit on option that follows a keyword splat" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, **route_options, on: :member
      end
    RUBY
  end

  test "registers offense for string action with on option" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        match "confirm", on: :member, via: :post
      end
    RUBY
  end

  test "registers offense inside singular resource" do
    assert_offense <<~RUBY, file: "config/routes.rb"
      resource :profile do
        member do
          get :preview
        end
      end
    RUBY
  end

  test "registers offense in a drawn routes file" do
    assert_offense <<~RUBY, file: "config/routes/admin.rb"
      resources :reports do
        post :publish, on: :member
      end
    RUBY
  end

  test "allows nested resources" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        resource :confirmation, only: :create
        resources :comments, only: [ :index, :create ]
      end
    RUBY
  end

  test "allows plain resources" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      resources :messages
      resource :profile, only: [ :show, :edit, :update ]
    RUBY
  end

  test "allows standalone routes without on option" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      root "welcome#show"
      get "up" => "rails/health#show", as: :rails_health_check
    RUBY
  end

  test "allows an on option that is not a literal scope" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, on: scope
      end
    RUBY
  end

  test "allows a route option with a dynamically computed key" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      resources :messages do
        get :preview, { route_option => :member }
      end
    RUBY
  end

  test "allows new with a receiver" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      CustomConstraint.new do
        resources :messages
      end
    RUBY
  end

  test "allows member block outside resources" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      member do
        post :confirm
      end
    RUBY
  end

  test "allows a member block nested under resources sent to an object" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      router.resources :messages do
        member do
          post :confirm
        end
      end
    RUBY
  end

  test "does not apply outside routes files" do
    assert_no_offense <<~RUBY, file: "app/models/subscription.rb"
      resources :messages do
        member do
          post :confirm
        end
      end
    RUBY
  end

  test "ignores route-shaped calls inside methods and deferred callables" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      def example
        post :publish, on: :member
      end

      callback = -> { delete :archive, on: :collection }
    RUBY
  end
end
