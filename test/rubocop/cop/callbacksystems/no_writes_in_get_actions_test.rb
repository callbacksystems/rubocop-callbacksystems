require "test_helper"

class RuboCop::Cop::Callbacksystems::NoWritesInGetActionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoWritesInGetActions

  test "registers offense for update! in show" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          @message = Message.find(params[:id])
          @message.update!(read_at: Time.current)
        end
      end
    RUBY
  end

  test "registers offense for touch in show" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          @message.touch
        end
      end
    RUBY
  end

  test "registers offense for create in new action" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def new
          @user = User.create
        end
      end
    RUBY
  end

  test "registers offense for destroy_all in index" do
    assert_offense <<~RUBY, file: "app/controllers/sessions_controller.rb"
      class SessionsController < ApplicationController
        def index
          Session.expired.destroy_all
        end
      end
    RUBY
  end

  test "registers offense for find_or_create_by in edit" do
    assert_offense <<~RUBY, file: "app/controllers/settings_controller.rb"
      class SettingsController < ApplicationController
        def edit
          @setting = Setting.find_or_create_by(user: current_user)
        end
      end
    RUBY
  end

  test "registers offense for perform_later in show" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          ReadReceiptJob.perform_later(params[:id])
        end
      end
    RUBY
  end

  test "registers offense for deliver_later in show" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          MessageMailer.opened(@message).deliver_later
        end
      end
    RUBY
  end

  test "registers offense for any method ending in _later" do
    assert_offense <<~RUBY, file: "app/controllers/boards_controller.rb"
      class BoardsController < ApplicationController
        def show
          @board.refresh_later
        end
      end
    RUBY
  end

  test "registers offense for deliver_now in show" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          MessageMailer.opened(@message).deliver_now
        end
      end
    RUBY
  end

  test "registers offense for write inside a block in the action" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          respond_to do |format|
            format.html { @message.touch }
          end
        end
      end
    RUBY
  end

  test "registers offense for safe navigation write" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          @message&.touch
        end
      end
    RUBY
  end

  test "allows writes in create" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def create
          @user = User.create!(user_params)
        end
      end
    RUBY
  end

  test "allows writes in update" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def update
          @user.update!(user_params)
        end
      end
    RUBY
  end

  test "allows writes in destroy" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def destroy
          @user.destroy!
        end
      end
    RUBY
  end

  test "allows reads in GET actions" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.active.order(:name)
        end

        def show
          @user = User.find(params[:id])
        end
      end
    RUBY
  end

  test "allows building an unsaved record in new" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def new
          @user = User.new
        end
      end
    RUBY
  end

  test "allows request state updates in GET actions" do
    assert_no_offense <<~RUBY, file: "app/controllers/sessions_controller.rb"
      class SessionsController < ApplicationController
        def new
          session.update(return_to: request.referer)
        end
      end
    RUBY
  end

  test "allows writes in methods pushed to the model" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          @message.mark_as_read
        end
      end
    RUBY
  end

  test "does not apply to non-controller classes" do
    assert_no_offense <<~RUBY, file: "app/models/message.rb"
      class Message < ApplicationRecord
        def show
          touch
        end
      end
    RUBY
  end
end
