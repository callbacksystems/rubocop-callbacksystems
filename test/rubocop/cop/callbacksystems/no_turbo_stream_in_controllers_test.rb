require "test_helper"

class RuboCop::Cop::Callbacksystems::NoTurboStreamInControllersTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoTurboStreamInControllers

  test "registers an explicitly self-qualified Turbo Stream builder" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      self.turbo_stream.replace(@message)
    RUBY
  end

  test "registers a safely navigated Turbo Stream builder" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      turbo_stream&.replace(@message)
    RUBY
  end

  test "registers offense for replace inside render turbo_stream" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def update
          render turbo_stream: turbo_stream.replace(@message, partial: "messages/form")
        end
      end
    RUBY
  end

  test "registers offense for append assigned to a local" do
    assert_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def create
          stream = turbo_stream.append("messages", partial: "messages/message")
          render turbo_stream: stream
        end
      end
    RUBY
  end

  test "registers one offense per builder call" do
    assert_offense <<~RUBY, count: 3, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def destroy
          render turbo_stream: [
            turbo_stream.remove(@message),
            turbo_stream.update("count", @messages.size),
            turbo_stream.replace("flash", partial: "layouts/flash")
          ]
        end
      end
    RUBY
  end

  test "reports the offense as uncorrectable" do
    assert_uncorrectable_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def update
          render turbo_stream: turbo_stream.replace(@message)
        end
      end
    RUBY
  end

  test "allows format.turbo_stream rendering the view" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def update
          respond_to do |format|
            format.turbo_stream { render status: :unprocessable_content }
          end
        end
      end
    RUBY
  end

  test "allows a builder call on another receiver" do
    assert_no_offense <<~RUBY, file: "app/controllers/messages_controller.rb"
      class MessagesController < ApplicationController
        def update
          render turbo_stream: helpers.turbo_stream.replace(@message)
        end
      end
    RUBY
  end

  test "does not apply outside controllers" do
    assert_no_offense <<~RUBY, file: "app/helpers/messages_helper.rb"
      module MessagesHelper
        def message_replacement
          turbo_stream.replace(@message, partial: "messages/form")
        end
      end
    RUBY
  end
end
