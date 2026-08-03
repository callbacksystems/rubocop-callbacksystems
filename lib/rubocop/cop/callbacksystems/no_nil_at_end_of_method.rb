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

    trailing = TrailingNil.new(last_statement_in(node.body), processed_source.comments)
    add_offense(trailing.node, message: MESSAGE) { trailing.remove(it) } if trailing.offense?
  end

  alias on_defs on_def

  private
    # The `nil` a method ends with, together with the separator that goes with it.
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

      # Drop the `nil` and the separator before it (newline or `;`), so the fix
      # works for both multi-line bodies and one-liners. A `nil` with no preceding
      # sibling, a lone statement in a `begin` block, is reported but left alone.
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

        def separator
          node.source_range.with(begin_pos: previous.source_range.end_pos)
        end
    end
end
