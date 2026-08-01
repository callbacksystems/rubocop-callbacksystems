# Keeps GET actions free of writes and enqueued side effects.
# Only applies to index, show, new, and edit in controller classes, and only
# to calls made directly in the action body, so a write pushed into a model
# method stays a deliberate choice.
#
# @example
#   # bad - GET action persists a change
#   class MessagesController < ApplicationController
#     def show
#       @message = Message.find(params[:id])
#       @message.update!(read_at: Time.current)
#     end
#   end
#
#   # bad - GET action enqueues a side effect
#   class MessagesController < ApplicationController
#     def show
#       ReadReceiptJob.perform_later(params[:id])
#     end
#   end
#
#   # good - the write moves behind a non-GET action
#   class Messages::ReadingsController < ApplicationController
#     def create
#       Message.find(params[:message_id]).update!(read_at: Time.current)
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoWritesInGetActions < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "`%<action>s` serves GET requests, so it must not call `%<method>s`. Move the write behind a non-GET action."

  def on_def(node)
    action = GetAction.new(node)
    action.writes.each { add_offense(it, message: action.offense_message(it)) }
  end

  private
    class GetAction
      include RuboCop::Callbacksystems::Helpers

      GET_ACTIONS = %i[index show new edit].freeze
      WRITE_METHODS = %i[
        create create! save save! update update! update_attribute update_column update_columns
        destroy destroy! destroy_all delete_all touch increment! decrement! toggle!
        find_or_create_by find_or_create_by! create_or_find_by create_or_find_by!
        first_or_create first_or_create! increment_counter decrement_counter update_counters
        insert_all insert_all! upsert upsert_all deliver_now perform_now
      ].freeze
      DEFERRED_SUFFIX = "_later"
      REQUEST_STATE_RECEIVERS = %i[session cookies flash params headers request response].freeze

      def initialize(node)
        @node = node
      end

      def writes
        if get_action?
          node.each_node(:call).select { write?(it) }
        else
          []
        end
      end

      def offense_message(write)
        format(MESSAGE, action: node.method_name, method: write.method_name)
      end

      private
        attr_reader :node

        def get_action?
          GET_ACTIONS.include?(node.method_name) && enclosing_controller_class? && public_method?(node)
        end

        def enclosing_controller_class?
          enclosing_class_or_module_of(node)&.then { it.class_type? && controller_superclass?(it.parent_class) }
        end

        def write?(call)
          write_name?(call.method_name) && !request_state_receiver?(call.receiver)
        end

        def write_name?(name)
          WRITE_METHODS.include?(name) || name.end_with?(DEFERRED_SUFFIX)
        end

        def request_state_receiver?(receiver)
          receiver&.send_type? && receiver.receiver.nil? && REQUEST_STATE_RECEIVERS.include?(receiver.method_name)
        end
    end
end
