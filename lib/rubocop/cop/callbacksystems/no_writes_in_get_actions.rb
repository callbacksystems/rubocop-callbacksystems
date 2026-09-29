# Keeps GET actions free of writes and enqueued side effects. HTTP promises a
# GET changes nothing, and browsers, crawlers and link previews act on that
# promise by prefetching, retrying and replaying it, so a write in `show` runs
# as many times as the page is opened and by clients that never meant to act.
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
  def on_def(node)
    report_each GetAction.new(node)
  end

  private
    class GetAction
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "`%<action>s` serves GET requests, so it must not call `%<method>s`. Move the write behind a non-GET " \
        "action."
      GET_ACTIONS = %i[ index show new edit ]
      WRITE_METHODS = %i[
        create create! save save! update update! update_attribute update_column update_columns
        destroy destroy! destroy_all delete delete_all update_all touch increment! decrement! toggle!
        find_or_create_by find_or_create_by! create_or_find_by create_or_find_by!
        first_or_create first_or_create! increment_counter decrement_counter update_counters
        insert_all insert_all! upsert upsert_all deliver_now perform_now
      ]
      DEFERRED_SUFFIX = "_later"
      REQUEST_STATE_RECEIVERS = %i[ session cookies flash params headers request response ]

      def initialize(node)
        @node = node
      end

      def each_offense
        writes.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :node

        def writes
          if get_action?
            node.each_node(:call).select { write?(it) && !inside_deferred_callable?(it) }
          else
            []
          end
        end

        def get_action?
          GET_ACTIONS.include?(node.method_name) && direct_method_definition?(node) && instance_method? &&
            enclosing_controller_class? && public_method?(node)
        end

        def instance_method?
          RuboCop::Callbacksystems::Methods::Domain.new(node).scope == :instance
        end

        def enclosing_controller_class?
          controller_class?(enclosing_class_or_module_of(node))
        end

        def write?(call)
          write_name?(call.method_name) && !RequestStateReceiver.new(call.receiver).request_state?
        end

        def write_name?(name)
          WRITE_METHODS.include?(name) || name.end_with?(DEFERRED_SUFFIX)
        end

        def inside_deferred_callable?(call)
          call.each_ancestor.take_while { !it.equal?(node) }.any? do |ancestor|
            ancestor.any_def_type? || deferred_callable_block?(ancestor)
          end
        end

        def message_for(write)
          format(MESSAGE, action: node.method_name, method: write.method_name)
        end

        class RequestStateReceiver
          def initialize(receiver)
            @receiver = receiver
          end

          def request_state?
            ReceiverPath.new(receiver).any? { request_state_reader?(it) }
          end

          private
            attr_reader :receiver

            def request_state_reader?(candidate)
              candidate.call_type? && REQUEST_STATE_RECEIVERS.include?(candidate.method_name) &&
                (candidate.receiver.nil? || candidate.receiver.self_type?)
            end

            class ReceiverPath
              include Enumerable

              def initialize(receiver)
                @receiver = receiver
              end

              def each
                if block_given?
                  current = receiver
                  until current.nil?
                    yield current
                    current = if current.begin_type? && current.children.one?
                      current.children.first
                    elsif current.call_type?
                      current.receiver
                    end
                  end
                else
                  to_enum(__method__)
                end
              end

              private
                attr_reader :receiver
            end
        end
    end
end
