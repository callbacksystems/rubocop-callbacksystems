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

    expected = EnqueueMethod.new(node, enclosing_class_methods(node)).expected_later_name
    add_offense(node, message: format(MESSAGE, name: node.method_name, expected: expected)) if expected
  end

  private
    def enclosing_class_methods(def_node)
      return Set.new unless (enclosing = def_node.each_ancestor(:class, :module).first)

      enclosing.each_descendant(:def).select { direct_child_of_class?(it, enclosing) }.to_set(&:method_name)
    end

    class EnqueueMethod
      attr_reader :node, :class_methods

      def initialize(node, class_methods)
        @node = node
        @class_methods = class_methods
      end

      def expected_later_name
        :"#{base_name}_later" if should_rename?(base_name)
      end

      private
        def base_name
          @base_name ||= begin
            perform_later_call = node.body&.each_node(:send)&.find { it.method?(:perform_later) }
            perform_later_call && base_name_for(perform_later_call)
          end
        end

        def should_rename?(base_name)
          base_name && class_methods.include?(base_name) && !node.method?(:"#{base_name}_later")
        end

        def base_name_for(perform_later_call)
          return unless perform_later_call.receiver

          job_class_name = job_class_name_for(perform_later_call.receiver)
          base = job_class_name&.end_with?("Job") && job_class_name.sub(/Job$/, "")
          base&.underscore&.to_sym
        end

        def job_class_name_for(receiver_node)
          case receiver_node.type
          when :const
            receiver_node.children.last.to_s
          when :send
            receiver_node.method_name.to_s
          end
        end
    end
end
