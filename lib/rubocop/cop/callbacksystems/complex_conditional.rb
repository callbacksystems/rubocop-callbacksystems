# Detects complex conditionals with too many boolean operators. Complex conditions should be extracted to predicate
# methods.
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
class RuboCop::Cop::Callbacksystems::ComplexConditional < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Conditional has %<count>d boolean operators (max %<max>d). Extract to a predicate method."

  def on_if(node)
    check_condition(node.condition)
  end

  alias on_while on_if
  alias on_until on_if

  private
    def check_condition(condition)
      count = operator_count_in(condition)
      add_offense(condition, message: format(MESSAGE, count: count, max: max_operators)) if count > max_operators
    end

    # An `and`/`or` buried in a sub-expression is that expression's complexity, not the predicate's.
    def operator_count_in(node)
      if node&.type?(:and, :or)
        1 + node.children.sum { operator_count_in(it) }
      else
        0
      end
    end

    def max_operators
      cop_config["MaxOperators"]
    end
end
