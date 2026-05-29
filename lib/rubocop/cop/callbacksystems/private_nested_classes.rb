# Requires nested classes to be declared in the private section.
# Nested classes are implementation details and should not be exposed publicly.
#
# @example
#   # bad - public nested class
#   class Order
#     class LineItem
#     end
#   end
#
#   # bad - nested class before private keyword
#   class Order
#     class LineItem
#     end
#
#     private
#       def process
#       end
#   end
#
#   # good - nested class in private section
#   class Order
#     def process
#     end
#
#     private
#       class LineItem
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateNestedClasses < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Nested class `%<name>s` should be in the private section at the end of the enclosing class."

  def on_class(node)
    nested = NestedClass.new(node)
    add_offense(node, message: nested.offense_message) if nested.offense?
  end

  private
    class NestedClass
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        enclosing = enclosing_class_or_module_of(node)
        enclosing && enclosing != node && private_nested_classes_in(enclosing).exclude?(node)
      end

      def offense_message
        format(MESSAGE, name: node.identifier.source)
      end

      private
        attr_reader :node
    end
end
