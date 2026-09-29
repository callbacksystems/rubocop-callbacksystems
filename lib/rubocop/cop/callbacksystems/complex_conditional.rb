# Detects complex conditionals with too many boolean operators. A condition
# chaining several operators has to be read term by term to know what it asks,
# while a predicate method names the question and holds the terms where they
# read on their own.
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
  alias on_while_post on_if
  alias on_until_post on_if

  private
    def check_condition(condition)
      count = OperatorCount.new(condition).value
      add_offense(condition, message: format(MESSAGE, count: count, max: max_operators)) if count > max_operators
    end

    def max_operators
      cop_config["MaxOperators"]
    end

    # The top-level boolean spine, walked iteratively so arbitrarily deep parser output cannot exhaust the call stack.
    class OperatorCount
      def initialize(node)
        @pending = [ node ]
        @count = 0
      end

      def value
        visit(pending.pop) until pending.empty?
        count
      end

      private
        attr_reader :pending, :count

        def visit(node)
          case node&.type
          when :and, :or then count_operator(node)
          when :begin, :kwbegin then pending << node.children.last
          end
        end

        def count_operator(node)
          @count += 1
          pending.concat(node.children)
        end
    end
end
