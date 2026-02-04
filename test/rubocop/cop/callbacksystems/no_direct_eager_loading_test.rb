require "test_helper"

class RuboCop::Cop::Callbacksystems::NoDirectEagerLoadingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoDirectEagerLoading

  test "registers offense for includes in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.includes(:posts)
        end
      end
    RUBY
  end

  test "registers offense for preload in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.preload(:comments)
        end
      end
    RUBY
  end

  test "registers offense for eager_load in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def show
          @user = User.eager_load(:profile).find(params[:id])
        end
      end
    RUBY
  end

  test "registers offense in nested controller" do
    assert_offense <<~RUBY, file: "app/controllers/admin/users_controller.rb"
      class Admin::UsersController < ApplicationController
        def index
          @users = User.includes(:posts, :comments)
        end
      end
    RUBY
  end

  test "allows includes in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
      end
    RUBY
  end

  test "allows preload in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_comments, -> { preload(:comments) }
      end
    RUBY
  end

  test "allows eager_load in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_profile, -> { eager_load(:profile) }
      end
    RUBY
  end

  test "allows scope usage in controller" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.with_posts.all
        end
      end
    RUBY
  end
end
