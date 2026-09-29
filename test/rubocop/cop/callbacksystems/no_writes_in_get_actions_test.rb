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

  test "allows writes in class methods written in a singleton section" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        class << self
          def show
            User.update_all(active: true)
          end
        end
      end
    RUBY
  end

  test "allows writes in a method owned by an anonymous class inside a controller" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        Handler = Class.new do
          def show
            User.update_all(active: true)
          end
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

  test "allows updates through a request state chain" do
    assert_no_offense <<~RUBY, file: "app/controllers/sessions_controller.rb"
      class SessionsController < ApplicationController
        def show
          response.headers.update("X-Frame-Options" => "DENY")
        end
      end
    RUBY
  end

  test "allows updates through a safely navigated request state chain" do
    assert_no_offense <<~RUBY, file: "app/controllers/sessions_controller.rb"
      class SessionsController < ApplicationController
        def show
          response&.headers&.update("X-Frame-Options" => "DENY")
        end
      end
    RUBY
  end

  test "allows updates through explicitly self-qualified and parenthesized request state" do
    assert_no_offense <<~RUBY, file: "app/controllers/sessions_controller.rb"
      class SessionsController < ApplicationController
        def show
          self.response.headers.update("X-Frame-Options" => "DENY")
          (session).update(return_to: request.referer)
        end
      end
    RUBY
  end

  test "recognizes a request-state chain deeper than Ruby's call stack" do
    response = RuboCop::AST::SendNode.new(:send, [ nil, :response ])
    receiver = 5_000.times.reduce(response) do |chain, _|
      RuboCop::AST::SendNode.new(:send, [ chain, :headers ])
    end

    request_state = RuboCop::Cop::Callbacksystems::NoWritesInGetActions::GetAction::RequestStateReceiver.new(receiver)
    receiver_path = RuboCop::Cop::Callbacksystems::NoWritesInGetActions::GetAction::RequestStateReceiver::ReceiverPath

    assert request_state.request_state?
    assert_equal 5_001, receiver_path.new(receiver).each.count
  end

  test "allows a write captured in a callable that the action does not execute" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          -> { Message.delete_all }
        end
      end
    RUBY
  end

  test "allows a write captured in a Proc constructor that the action does not execute" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          operation = Proc.new { Message.delete_all }
          render json: operation
        end
      end
    RUBY
  end

  test "allows a write in a nested instance method definition" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          def delete_all
            Message.delete_all
          end
        end
      end
    RUBY
  end

  test "allows a write in a nested singleton method definition" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def show
          def self.delete_all
            Message.delete_all
          end
        end
      end
    RUBY
  end

  test "registers offense for update_all in index" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def index
          Message.unread.update_all(read_at: Time.current)
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

  test "allows a method written at the top level, outside any controller" do
    assert_no_offense <<~RUBY
      def show
        Post.create!(title: "one")
      end
    RUBY
  end

  test "registers offense for a write called without a receiver" do
    assert_offense <<~RUBY, file: "app/controllers/widgets_controller.rb"
      class WidgetsController < ApplicationController
        def show
          update!(status: "seen")
        end
      end
    RUBY
  end
end
