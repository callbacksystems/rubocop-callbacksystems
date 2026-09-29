# Detects `each` blocks that `return` an element from inside a condition. The
# loop is a search written by hand, and `find` says so in one line, while the
# `each` form makes a reader trace the `return` to learn that the method hands
# back the first match and `nil` otherwise.
#
# @example
#   # bad - each with early return
#   items.each do |item|
#     return item if item.valid?
#   end
#   nil
#
#   # good - use find
#   items.find { it.valid? }
#
#   # bad - each with early return (implicit nil)
#   def find_valid
#     items.each do |item|
#       return item if item.valid?
#     end
#   end
#
#   # good
#   def find_valid
#     items.find { it.valid? }
#   end
#
class RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturn < RuboCop::Cop::Callbacksystems::Base
  def on_block(node)
    report EachBlock.new(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class EachBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Don't use `each` with early `return`. Use `find` instead."

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE) if node.method?(:each) && returns_conditionally?
      end

      private
        attr_reader :node

        def returns_conditionally?
          RuboCop::Callbacksystems::Execution::Immediate.new(node.body).nodes_of_type(:return)
            .any? { conditional_return_of_block_argument?(it, block: node) }
        end
    end
end
