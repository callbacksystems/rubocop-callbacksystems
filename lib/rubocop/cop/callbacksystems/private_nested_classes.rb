# Requires nested classes to be declared in the private section. A nested class is an implementation detail, so the
# class holding one says as much by where it puts it. One that other files build has no business being nested at all: it
# goes in its own file, where Zeitwerk expects it.
#
# A constant assigned from `Data.define`, `Struct.new` or `Class.new` defines a class in everything but syntax, so it
# reads under the same rule.
#
# A definition with no body is left alone. An error class or a bare list of members declares what something is rather
# than how it works, and a file of its own would cost more than it says.
#
# @example
#   # bad - public nested class
#   class Order
#     class LineItem
#       def total
#       end
#     end
#   end
#
#   # bad - a constant that builds a class with behavior
#   class Order
#     LineItem = Data.define(:sku, :quantity) do
#       def total
#       end
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
#         def total
#         end
#       end
#   end
#
#   # good - declarations with no body, wherever they read best
#   class Order
#     class Rejected < StandardError; end
#
#     LineItem = Data.define(:sku, :quantity)
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateNestedClasses < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Nested class `%<name>s` should be in the private section, or live in its own file if it is part of the API."

  def on_class(node)
    nested = NestedClass.new(node)
    add_offense(node, message: nested.offense_message) if nested.offense?
  end

  alias on_casgn on_class

  private
    class NestedClass
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        class_with_body?(node) && nested? && !in_private_section?(node, enclosing.body)
      end

      def offense_message
        format(MESSAGE, name: class_name_of(node))
      end

      private
        attr_reader :node

        def nested?
          enclosing.present?
        end

        def enclosing
          @enclosing ||= enclosing_class_or_module_of(node)
        end
    end
end
