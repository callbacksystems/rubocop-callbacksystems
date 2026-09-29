# Prohibits defining methods named `call`, except for Rack middleware endpoints.
# This pattern is associated with service objects which we avoid.
#
# @example
#   # bad
#   class OrderProcessor
#     def call
#       # ...
#     end
#   end
#
#   # bad
#   class OrderProcessor
#     def self.call
#       # ...
#     end
#   end
#
#   # good - use descriptive method names
#   class Order
#     def process
#       # ...
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoCallMethod < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Avoid defining `call` methods. Use descriptive method names instead."

  def on_def(node)
    report MethodName.new(node)
  end

  alias on_defs on_def

  private
    class MethodName
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE) if node.method?(:call) && !rack_protocol?
      end

      private
        attr_reader :node

        def rack_protocol?
          direct_method_definition?(node) && instance_method? && parameter_names_of(node) == [ "env" ] &&
            rack_middleware_class?
        end

        def instance_method?
          RuboCop::Callbacksystems::Methods::Domain.new(node).scope == :instance
        end

        def rack_middleware_class?
          class_node.class_type? && (class_name_of(class_node).end_with?("Middleware") || accepts_rack_application?)
        end

        def class_node
          @class_node ||= enclosing_class_or_module_of(node)
        end

        def accepts_rack_application?
          direct_method_nodes_in(class_node.body).any? do |method_node|
            method_node.method?(:initialize) && parameter_names_of(method_node).include?("app")
          end
        end
    end
end
