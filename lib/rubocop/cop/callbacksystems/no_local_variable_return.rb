# Prohibits returning a local variable as the last statement of a method.
# Use `.tap`, `.then`, `each_with_object`, or return the expression directly instead.
#
# @example
#   # bad - returning a local variable
#   def process
#     result = calculate_something
#     result
#   end
#
#   # bad - assign, mutate, return
#   def process
#     result = []
#     result << item
#     result
#   end
#
#   # bad - explicit return of local variable
#   def process
#     result = {}
#     result[:key] = value
#     return result
#   end
#
#   # good - return the expression directly
#   def process
#     calculate_something
#   end
#
#   # good - use tap
#   def process
#     [].tap do |result|
#       result << item
#     end
#   end
#
#   # good - use each_with_object
#   def process
#     items.each_with_object([]) do |item, result|
#       result << transform(item)
#     end
#   end
#
#   # good - use then
#   def process
#     calculate_something.then do |result|
#       result.merge(extra: value)
#     end
#   end
#
#   # good - declarative approach
#   def process
#     [item]
#   end
#
class RuboCop::Cop::Callbacksystems::NoLocalVariableReturn < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::Helpers

  MESSAGE = "Avoid returning a local variable. " \
    "Return the expression directly, or use `.tap`, `.then`, or `each_with_object`."

  def on_def(node)
    last = node.body && last_statement(node.body)
    add_offense(last, message: MESSAGE) if last && returns_local_variable?(last)
  end

  alias on_defs on_def

  private
    def returns_local_variable?(statement)
      statement.lvar_type? || (statement.return_type? && statement.children.first&.lvar_type?)
    end
end
