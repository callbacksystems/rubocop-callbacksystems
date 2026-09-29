# Forbids nested modules inside classes.
# Modules should be defined at the top level or inside other modules,
# not inside classes.
#
# Nested modules in classes are often used to avoid creating proper
# objects, leading to imperative rather than declarative code.
#
# @example
#   # bad - nested module in class
#   class Order
#     module Calculations
#       def total
#         # ...
#       end
#     end
#   end
#
#   # bad - nested module in private section
#   class Order
#     private
#       module Calculations
#         def total
#           # ...
#         end
#       end
#   end
#
#   # good - use a nested class instead
#   class Order
#     private
#       class Calculator
#         def total
#           # ...
#         end
#       end
#   end
#
#   # good - define module at top level
#   module Order::Calculations
#     def total
#       # ...
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoNestedModulesInClasses < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Do not nest modules inside classes. Use a nested class or define the module at the top level."

  def on_module(node)
    report NestedModule.new(node)
  end

  alias on_casgn on_module

  private
    class NestedModule
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE) if declaration? && inside_class?
      end

      private
        attr_reader :node

        def declaration?
          node.module_type? ||
            RuboCop::Callbacksystems::ClassStructure::BuilderAssignment.new(node).builds_module?
        end

        def inside_class?
          enclosing_class_or_module_of(node)&.class_type?
        end
    end
end
