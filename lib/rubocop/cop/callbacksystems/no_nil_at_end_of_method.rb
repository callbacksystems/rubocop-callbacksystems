# Prohibits returning nil at the end of a method. Having `nil` as the last line is unnecessary and indicates poor
# design. Exception: when `nil` is the only statement (clearly intentional, e.g., interface methods).
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
# The correction is not safe, and is marked so: dropping the `nil` hands back
# whatever the statement above it evaluates to, where the method used to answer
# `nil`. That is the point of the rule, since a method reaching its end already
# answers `nil` unless something else is being returned by accident, but it is a
# change in what callers see, so it waits for the unsafe autocorrect pass.
#
class RuboCop::Cop::Callbacksystems::NoNilAtEndOfMethod < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Avoid `nil` at the end of a method. Restructure the code to make it unnecessary."

  def on_def(node)
    return if node.body&.nil_type?

    trailing = TrailingNil.new(last_statement_in(node.body), processed_source.comments)
    add_offense(trailing.node, message: MESSAGE) { trailing.remove(it) } if trailing.offense?
  end

  alias on_defs on_def

  private
    class TrailingNil
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def offense?
        node&.nil_type?
      end

      # The separator goes too, so the fix works for a one-liner. A `nil` with no preceding sibling is reported but left
      # alone.
      def remove(corrector)
        corrector.remove(removal_range) if previous
      end

      private
        attr_reader :comments

        def previous
          node.left_sibling
        end

        # A comment in that separator keeps its place under the statement above it.
        def removal_range
          range_starting_after_last_comment(separator, comments)
        end

        # Measured past any heredoc body hanging below the statement above.
        def separator
          node.source_range.with(begin_pos: source_end_of(previous))
        end
    end
end
