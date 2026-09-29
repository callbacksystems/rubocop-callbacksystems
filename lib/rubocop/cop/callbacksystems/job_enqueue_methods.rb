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
  def on_new_investigation
    @sibling_methods = RuboCop::Callbacksystems::Methods::Siblings.new
  end

  def on_def(node)
    report EnqueueMethod.new(node, sibling_methods:) unless node.method_name.to_s.end_with?("_later")
  end

  alias on_defs on_def

  private
    attr_reader :sibling_methods

    # A method enqueuing a job, read for the work method its job is named after.
    class EnqueueMethod
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Rename `%<name>s` to `%<expected>s` to follow the _later convention."

      def initialize(node, sibling_methods:)
        @node = node
        @sibling_methods = sibling_methods
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if pairs_with_work_method?
      end

      private
        attr_reader :node, :sibling_methods

        def pairs_with_work_method?
          base_name && sibling_methods.named(base_name, beside: node).any?
        end

        def base_name
          @base_name ||= job_class_name.delete_suffix("Job").underscore.to_sym if job_class_name.end_with?("Job")
        end

        def job_class_name
          @job_class_name ||= class_name_of(perform_later_call&.receiver).to_s
        end

        def class_name_of(receiver)
          case receiver&.type
          when :const then receiver.short_name
          when :send then receiver.method_name
          end
        end

        def perform_later_call
          RuboCop::Callbacksystems::Execution::Immediate.new(node.body).find do |candidate|
            candidate.call_type? && candidate.method?(:perform_later)
          end
        end

        def message
          format(MESSAGE, name: node.method_name, expected: :"#{base_name}_later")
        end
    end
end
