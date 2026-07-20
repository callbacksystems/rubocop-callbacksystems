# Requires nested classes to be declared in the private section. A nested class
# is an implementation detail, so the class holding one says as much by where it
# puts it. One that other files build has no business being nested at all: it
# goes in its own file, where Zeitwerk expects it.
#
# A constant assigned from `Data.define`, `Struct.new` or `Class.new` defines a
# class in everything but syntax, so it reads under the same rule.
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
#   # bad - a constant that defines a class
#   class Order
#     LineItem = Data.define(:sku, :quantity)
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
#       LineItem = Data.define(:sku, :quantity)
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateNestedClasses < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Nested class `%<name>s` should be in the private section, or live in its own file if it is part of the API."
  CLASS_BUILDERS = { Data: :define, Struct: :new, Class: :new }.freeze

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
        class_definition? && nested? && !in_private_section?(node, enclosing.body)
      end

      def offense_message
        format(MESSAGE, name: name)
      end

      private
        attr_reader :node

        def class_definition?
          node.class_type? || builds_class?
        end

        def builds_class?
          node.casgn_type? && class_builder?(builder_call)
        end

        def class_builder?(call)
          call&.send_type? && CLASS_BUILDERS[builder_name_of(call)] == call.method_name
        end

        def builder_name_of(call)
          call.receiver.short_name if call.receiver&.const_type?
        end

        def builder_call
          node.expression&.then { any_block_type?(it) ? it.send_node : it }
        end

        def nested?
          enclosing.present?
        end

        def enclosing
          @enclosing ||= enclosing_class_or_module_of(node)
        end

        def name
          node.class_type? ? node.identifier.source : node.name.to_s
        end
    end
end
