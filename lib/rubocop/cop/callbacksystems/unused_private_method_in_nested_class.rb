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
    private_nested_classes_in(node).each do |nested_class|
      UnusedMethodDetector.new(nested_class).each_offense do |offense_node, message|
        add_offense(offense_node, message: message)
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

      def each_offense(&block)
        if block
          unused_methods.each { yield it, format(MESSAGE, method: it.method_name, class: class_name) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :nested_class, :class_name

        def unused_methods
          provable? ? uncalled_methods : []
        end

        # A superclass calls the hooks its subclass overrides, from outside this file.
        def provable?
          nested_class.parent_class.nil?
        end

        def uncalled_methods
          private_methods_in(nested_class).reject do |method_node|
            called_methods.include?(method_node.method_name) || macro_referenced_methods.include?(method_node.method_name)
          end
        end

        def called_methods
          @called_methods ||= Set.new(receiverless_method_names_in(nested_class.body))
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::MacroReferencedMethods.for(nested_class.body)
        end
    end
end
