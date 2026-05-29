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
class RuboCop::Cop::Callbacksystems::NoNilAtEndOfMethod < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Avoid `nil` at the end of a method. Restructure the code to make it unnecessary."

  def on_def(node)
    return if node.body&.nil_type?

    last = last_statement_in(node.body)
    add_offense(last, message: MESSAGE) { remove_trailing_nil(it, last) } if last&.nil_type?
  end

  alias on_defs on_def

  private
    # Drop the `nil` and the separator before it (newline or `;`), so the fix works
    # for both multi-line bodies and one-liners. A `nil` with no preceding sibling
    # (a lone statement in a `begin` block) is reported but left alone.
    def remove_trailing_nil(corrector, nil_node)
      previous = nil_node.left_sibling
      corrector.remove(nil_node.source_range.with(begin_pos: previous.source_range.end_pos)) if previous
    end
end
