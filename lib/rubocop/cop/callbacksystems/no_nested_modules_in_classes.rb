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
    return unless enclosing_class?(node)

    add_offense(node, message: MESSAGE)
  end

  private
    def enclosing_class?(node)
      node.each_ancestor(:class, :module).first&.class_type?
    end
end
