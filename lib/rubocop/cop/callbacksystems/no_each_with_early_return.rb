# Detects each blocks with conditional early returns that should use find.
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
class RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturn < RuboCop::Cop::Base
  MESSAGE = "Don't use `each` with early `return`. Use `find` instead."

  def on_block(node)
    add_offense(node, message: MESSAGE) if EachBlock.new(node).offense?
  end

  alias on_numblock on_block

  private
    class EachBlock
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        node.method?(:each) && has_conditional_return?
      end

      private
        def has_conditional_return?
          node.body&.each_node(:return)&.any? { |return_node| return_node.parent&.if_type? }
        end
    end
end
