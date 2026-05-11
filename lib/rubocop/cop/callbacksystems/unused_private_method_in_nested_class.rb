# Detects unused private methods in private nested classes.
# Since the nested class is private, no external code can inherit from it,
# so we can detect unused private methods within the same file.
#
# @example
#   # bad - unused private method
#   class Foo
#     def process
#       Bar.new.run
#     end
#
#     private
#       class Bar
#         def run
#           helper
#         end
#
#         private
#           def helper; end
#           def unused; end  # never called
#       end
#   end
#
#   # good - all private methods are used
#   class Foo
#     def process
#       Bar.new.run
#     end
#
#     private
#       class Bar
#         def run
#           helper
#         end
#
#         private
#           def helper; end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::UnusedPrivateMethodInNestedClass < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Private method `%<method>s` in nested class `%<class>s` is never called. Remove it."

  def on_class(node)
    private_nested_classes(node).each do |nested_class|
      UnusedMethodDetector.new(nested_class).detect.each do |method_node, klass_name|
        add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: klass_name))
      end
    end
  end

  alias on_module on_class

  private
    class UnusedMethodDetector
      include RuboCop::Callbacksystems::Helpers

      def initialize(nested_class)
        @nested_class = nested_class
        @class_name = nested_class.identifier.short_name
      end

      def detect
        private_methods_in(nested_class).filter_map do |method_node|
          [ method_node, class_name ] if called_methods.exclude?(method_node.method_name) && macro_referenced_methods.exclude?(method_node.method_name)
        end
      end

      private
        attr_reader :nested_class, :class_name

        def called_methods
          @called_methods ||= nested_class.body ? Set.new(nested_class.body.each_node(:send).filter_map { it.method_name if it.receiver.nil? }) : Set.new
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= nested_class.body ? RuboCop::Callbacksystems::MacroReferencedMethods.new(nested_class.body).collect : Set.new
        end
    end
end
