# Prohibits returning nil at the end of a method.
# Having `nil` as the last line is unnecessary and indicates poor design.
# Exception: when `nil` is the only statement (clearly intentional, e.g., interface methods).
#
# @example
#   # bad
#   def process
#     do_something
#     nil
#   end
#
#   # bad
#   def process
#     if condition
#       do_something
#     end
#     nil
#   end
#
#   # good - return value is implicit
#   def process
#     do_something
#   end
#
#   # good - use early return if needed
#   def process
#     return unless condition
#     do_something
#   end
#
#   # good - nil is clearly intentional (only statement)
#   def some_interface_method
#     nil
#   end
#
class RuboCop::Cop::Callbacksystems::NoNilAtEndOfMethod < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::Helpers

  MESSAGE = "Avoid `nil` at the end of a method. Restructure the code to make it unnecessary."

  def on_def(node)
    return if node.body&.nil_type?

    last = node.body && last_statement(node.body)
    add_offense(last, message: MESSAGE) if last&.nil_type?
  end

  alias on_defs on_def
end
