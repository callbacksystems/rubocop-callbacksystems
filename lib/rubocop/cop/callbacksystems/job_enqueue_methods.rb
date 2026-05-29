# Ensures methods that enqueue jobs follow the `_later` naming convention.
# This cop only flags when there's a corresponding method that does the actual work.
#
# The convention is to have paired methods:
# - `process` - does the actual work
# - `process_later` - enqueues a job that calls `process`
#
# @example
#   # bad - work method exists, job method should be named process_later
#   def enqueue_process
#     ProcessJob.perform_later(self)
#   end
#
#   def process
#     # actual work
#   end
#
#   # good - follows naming convention
#   def process_later
#     ProcessJob.perform_later(self)
#   end
#
#   def process
#     # actual work
#   end
#
#   # good - no corresponding work method, so no flag
#   def notify
#     NotificationJob.perform_later(self)
#   end
#
class RuboCop::Cop::Callbacksystems::JobEnqueueMethods < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Rename `%<name>s` to `%<expected>s` to follow the _later convention."

  def on_def(node)
    return if node.method_name.to_s.end_with?("_later")

    enqueue = EnqueueMethod.new(node, enclosing_class_methods(node))
    add_offense(node, message: enqueue.offense_message) if enqueue.offense?
  end

  alias on_defs on_def

  private
    def enclosing_class_methods(def_node)
      direct_method_nodes_in(enclosing_class_or_module_of(def_node)&.body).to_set(&:method_name)
    end

    class EnqueueMethod
      def initialize(node, class_methods)
        @node = node
        @class_methods = class_methods
      end

      def offense?
        !expected_later_name.nil?
      end

      def offense_message
        format(MESSAGE, name: node.method_name, expected: expected_later_name)
      end

      private
        attr_reader :node, :class_methods

        def expected_later_name
          @expected_later_name ||= :"#{base_name}_later" if base_name && rename?
        end

        def base_name
          return @base_name if defined?(@base_name)

          @base_name = perform_later_call&.then { base_name_for(it) }
        end

        def perform_later_call
          node.body&.each_node(:send)&.find { it.method?(:perform_later) }
        end

        def base_name_for(perform_later_call)
          if perform_later_call.receiver
            job_class_name = job_class_name_for(perform_later_call.receiver)
            base = job_class_name&.end_with?("Job") && job_class_name.sub(/Job$/, "")
            base&.underscore&.to_sym
          end
        end

        def job_class_name_for(receiver_node)
          case receiver_node.type
          when :const then receiver_node.short_name.to_s
          when :send then receiver_node.method_name.to_s
          end
        end

        def rename?
          class_methods.include?(base_name) && !node.method?(:"#{base_name}_later")
        end
    end
end
