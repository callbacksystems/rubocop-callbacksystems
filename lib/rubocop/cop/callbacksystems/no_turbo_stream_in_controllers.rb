# Keeps Turbo Stream markup out of controllers. A call on the `turbo_stream`
# tag builder renders elements, and markup belongs to the view, where the same
# `turbo_stream.replace` reads as a template while the controller only decides
# what to render and with which status.
#
# @example
#   # bad - the controller builds the stream
#   class MessagesController < ApplicationController
#     def update
#       if @message.update(message_params)
#         redirect_to @message
#       else
#         render turbo_stream: turbo_stream.replace(@message, partial: "messages/form")
#       end
#     end
#   end
#
#   # good - the controller renders and the view builds the stream
#   class MessagesController < ApplicationController
#     def update
#       if @message.update(message_params)
#         redirect_to @message
#       else
#         respond_to do |format|
#           format.turbo_stream { render status: :unprocessable_content }
#         end
#       end
#     end
#   end
#
#   # app/views/messages/update.turbo_stream.erb
#   <%= turbo_stream.replace @message, partial: "messages/form" %>
#
class RuboCop::Cop::Callbacksystems::NoTurboStreamInControllers < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Build the Turbo Stream in a `.turbo_stream.erb` view instead of calling `turbo_stream.%<method>s` in " \
    "the controller."

  def on_send(node)
    add_offense(node, message: format(MESSAGE, method: node.method_name)) if turbo_stream_builder_call?(node)
  end

  alias on_csend on_send

  private
    def turbo_stream_builder_call?(node)
      controller_file?(processed_source.file_path) && turbo_stream_builder?(node.receiver)
    end

    def turbo_stream_builder?(receiver)
      call_on_self?(receiver) && receiver.method?(:turbo_stream)
    end
end
