# Prohibits returning nil at the end of a method. A trailing `nil` is there to
# hide the value of the statement above it, which means a caller reads the
# method for a value it was never meant to give, so the method wants a shape
# whose last statement is its result. A `nil` that is the only statement is
# intentional, as in an interface method, and stays.
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
  def on_def(node)
    report TrailingNil.new(node)
  end

  alias on_defs on_def

  private
    class TrailingNil
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Avoid `nil` at the end of a method. Restructure the code to make it unnecessary."

      def initialize(method_node)
        @method_node = method_node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(last, MESSAGE) if trailing?
      end

      private
        attr_reader :method_node

        def trailing?
          last&.nil_type? && previous
        end

        def last
          @last ||= last_statement_in(method_node.body)
        end

        def previous
          last.left_sibling if last.parent.type?(:begin, :kwbegin)
        end
    end
end
