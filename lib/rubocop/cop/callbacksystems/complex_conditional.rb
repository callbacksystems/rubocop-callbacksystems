# Detects complex conditionals with too many boolean operators.
# Complex conditions should be extracted to predicate methods.
#
# @example MaxOperators: 1 (default)
#   # bad - too many operators
#   if a && b && c
#     # ...
#   end
#
#   # good - extract to predicate method
#   if complex_condition?
#     # ...
#   end
#
#   def complex_condition?
#     a && b && c
#   end
#
#   # good - single operator
#   if a && b
#     # ...
#   end
#
class RuboCop::Cop::Callbacksystems::ComplexConditional < RuboCop::Cop::Base
  MESSAGE = "Conditional has %<count>d boolean operators (max %<max>d). Extract to a predicate method."

  def on_if(node)
    count = operator_count(node.condition)
    add_offense(node.condition, message: format(MESSAGE, count: count, max: max_operators)) if count > max_operators
  end

  private
    def operator_count(node)
      return 0 unless node

      node.each_node(:and, :or).count
    end

    def max_operators
      cop_config["MaxOperators"] || 1
    end
end
