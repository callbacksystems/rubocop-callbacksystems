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
class RuboCop::Cop::Callbacksystems::JobEnqueueMethods < RuboCop::Cop::Base
  MESSAGE = "Rename `%<name>s` to `%<expected>s` to follow the _later convention."

  def on_new_investigation
    @class_methods = Set.new
  end

  def on_class(node)
    @class_methods = collect_class_methods(node)
  end

  def on_module(node)
    @class_methods = collect_class_methods(node)
  end

  def on_def(node)
    return if node.method_name.to_s.end_with?("_later")

    expected = EnqueueMethod.new(node, class_methods).expected_later_name
    add_offense(node, message: format(MESSAGE, name: node.method_name, expected: expected)) if expected
  end

  private
    attr_reader :class_methods

    def collect_class_methods(class_or_module_node)
      class_or_module_node.each_descendant(:def).select do |def_node|
        direct_child_of_class?(def_node, class_or_module_node)
      end.to_set(&:method_name)
    end

    def direct_child_of_class?(method_node, class_node)
      method_node.each_ancestor(:class, :module).first == class_node
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
            perform_later_call = node.body&.each_node(:send)&.find { it.method_name == :perform_later }
            perform_later_call && base_name_for(perform_later_call)
          end
        end

        def should_rename?(base_name)
          base_name && class_methods.include?(base_name) && node.method_name != :"#{base_name}_later"
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
