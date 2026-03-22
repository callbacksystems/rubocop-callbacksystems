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
class RuboCop::Cop::Callbacksystems::PrivateNestedClasses < RuboCop::Cop::Base
  MESSAGE = "Nested class `%<name>s` should be in the private section at the end of the enclosing class."

  def on_class(node)
    add_offense(node, message: format(MESSAGE, name: node.identifier.source)) if NestedClass.new(node).offense?
  end

  def on_sclass(node)
    # Skip singleton class definitions (class << self)
  end

  private
    class NestedClass
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        enclosing = enclosing_class_or_module
        enclosing && enclosing != node && RuboCop::Callbacksystems::Helpers.private_nested_classes(enclosing).exclude?(node)
      end

      private
        def enclosing_class_or_module
          node.each_ancestor(:class, :module).first
        end
    end
end
