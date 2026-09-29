require "test_helper"

class RuboCop::Cop::Callbacksystems::RoutesModuleScopeTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RoutesModuleScope

  test "allows routes whose module option repeats outside a shared parent" do
    assert_no_offense <<~RUBY
      Rails.application.routes.draw do
        get "one", module: :admin
        namespace :other do
        end
        get "two", module: :admin
      end
    RUBY
  end

  test "allows a module option repeated under two parents written alike" do
    assert_no_offense <<~RUBY
      Rails.application.routes.draw do
        resources :carts do
          resources :rules do
            resource :selections, module: :rules
          end
        end
        namespace :public do
          resources :rules do
            resource :selections, module: :rules
          end
        end
      end
    RUBY
  end

  test "keeps routes in separate implicit parameter blocks in separate groups" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        scope "/one" do
          constrain(it)
          resources :users, module: :admin
        end

        scope "/two" do
          constrain(it)
          resources :posts, module: :admin
        end
      end
    RUBY
  end

  test "allows a routes file with no code" do
    assert_no_offense ""
  end

  test "reads a module option that is neither a symbol nor a string" do
    assert_no_offense <<~RUBY
      Rails.application.routes.draw do
        get "one", module: NAMESPACE
      end
    RUBY
  end

  test "ignores a dynamic hash key without crashing" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "one", option_name => :admin
        get "two", option_name => :admin
      end
    RUBY
  end

  test "ignores route-like calls sent to an explicit receiver" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        router.get "one", module: :admin
        router.get "two", module: :admin
      end
    RUBY
  end

  test "registers offense for repeated module option" do
    offenses = assert_offense <<~RUBY, count: 2, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
    assert_includes offenses.first.message, "Extract repeated `module: :admin` to a `scope module: :admin do` block."
  end

  test "registers offense for three repeated module options" do
    assert_offense <<~RUBY, count: 3, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
        resources :comments, module: :admin
      end
    RUBY
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
    assert_offense <<~RUBY, count: 2, file: "config/routes/admin.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
  end

  test "consolidates routes written bare in a file drawn from config/routes" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes/admin.rb"
      resources :users, module: :admin
      resources :posts, module: :admin
    RUBY
      scope module: :admin do
        resources :users
        resources :posts
      end
    CORRECTED
  end

  test "handles get/post with module option" do
    assert_offense <<~RUBY, count: 2, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "/dashboard", to: "dashboard#index", module: :admin
        post "/login", to: "sessions#create", module: :admin
      end
    RUBY
  end

  test "consolidates contiguous routes into a scope block" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :posts, module: :admin
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          resources :users
          resources :posts
        end
      end
    CORRECTED
  end

  test "leaves routes carrying heredocs for a human rather than detaching their bodies" do
    assert_uncorrectable_offense <<~RUBY, count: 2, file: "config/routes.rb"
      Rails.application.routes.draw do
        get <<~FIRST, module: :admin
          /first
        FIRST
        get <<~SECOND, module: :admin
          /second
        SECOND
      end
    RUBY
  end

  test "preserves other route options when consolidating" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, module: :admin, only: [:index]
        get "/dashboard", to: "dashboard#index", module: :admin
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          resources :users, only: [:index]
          get "/dashboard", to: "dashboard#index"
        end
      end
    CORRECTED
  end

  test "preserves an option with a dynamic key when consolidating" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "one", option_name => true, module: :admin
        get "two", option_name => false, module: :admin
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          get "one", option_name => true
          get "two", option_name => false
        end
      end
    CORRECTED
  end

  test "preserves keyword splats overridden by the explicit module option" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "one", **defaults, module: :admin
        get "two", **overrides, module: :admin
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          get "one", **defaults
          get "two", **overrides
        end
      end
    CORRECTED
  end

  test "ignores an explicit module option that a following keyword splat can override" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "one", module: :admin, **defaults
        get "two", module: :admin, **defaults
      end
    RUBY
  end

  test "uses the last duplicate module option but leaves its consolidation to a human" do
    source = <<~RUBY
      Rails.application.routes.draw do
        get "one", module: :legacy, module: :admin
        get "two", module: :public, module: :admin
      end
    RUBY

    offenses = assert_offense source, count: 2, file: "config/routes.rb"

    assert_includes offenses.first.message, "module: :admin"
    assert_no_correction source, file: "config/routes.rb"
  end

  test "consolidates a module option that is the route's only argument" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        root module: :admin
        root({ module: :admin })
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          root
          root
        end
      end
    CORRECTED
  end

  test "removes an explicit module options hash after a positional argument" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, { module: :admin }
        resources(:posts, { module: :admin })
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          resources :users
          resources(:posts)
        end
      end
    CORRECTED
  end

  test "preserves the other pairs in an explicit options hash" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        resources :users, { module: :admin, only: :index }
        resources :posts, { only: :show, module: :admin }
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          resources :users, { only: :index }
          resources :posts, { only: :show }
        end
      end
    CORRECTED
  end

  test "removes a sole explicit options hash before another argument" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "config/routes.rb"
      Rails.application.routes.draw do
        get({ module: :admin }, "one")
        get({ module: :admin }, "two")
      end
    RUBY
      Rails.application.routes.draw do
        scope module: :admin do
          get("one")
          get("two")
        end
      end
    CORRECTED
  end

  test "does not autocorrect when routes are not contiguous" do
    unchanged = <<~RUBY
      Rails.application.routes.draw do
        resources :users, module: :admin
        resources :sessions
        resources :posts, module: :admin
      end
    RUBY
    assert_correction unchanged, unchanged, file: "config/routes.rb"
  end

  test "does not autocorrect across an intervening comment" do
    unchanged = <<~RUBY
      Rails.application.routes.draw do
        resources :users, module: :admin
        # keep these apart
        resources :posts, module: :admin
      end
    RUBY
    assert_correction unchanged, unchanged, file: "config/routes.rb"
  end

  test "registers offense for a module option repeated as a constant" do
    source = <<~RUBY
      Rails.application.routes.draw do
        get "one", module: NAMESPACE
        get "two", module: NAMESPACE
      end
    RUBY

    assert_uncorrectable_offense source, file: "config/routes.rb"
  end

  test "reports without correcting a repeated module expression" do
    source = <<~RUBY
      Rails.application.routes.draw do
        get "one", module: namespace_for("one")
        get "two", module: namespace_for("one")
      end
    RUBY

    assert_uncorrectable_offense source, file: "config/routes.rb"
  end

  test "does not combine symbol and string module values" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      Rails.application.routes.draw do
        get "one", module: :admin
        get "two", module: "admin"
      end
    RUBY
  end

  test "ignores route-shaped calls inside methods and deferred callables" do
    assert_no_offense <<~RUBY, file: "config/routes.rb"
      def examples
        resources :users, module: :admin
        resources :posts, module: :admin
      end

      callback = -> do
        resources :comments, module: :admin
        resources :events, module: :admin
      end
    RUBY
  end
end
