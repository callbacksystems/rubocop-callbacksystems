# Detects imperative collection building that could be written declaratively.
#
# Ruby favors declarative code that reads like prose. Instead of building collections imperatively with each/<<, use
# map, select, filter_map, etc.
#
# @example
#   # bad - imperative with mutation
#   results = []
#   items.each { |item| results << item.name }
#
#   # good - declarative
#   results = items.map(&:name)
#
# @example
#   # bad - imperative with conditional
#   results = []
#   items.each { |item| results << item if item.active? }
#
#   # good - declarative
#   results = items.select(&:active?)
#
# @example
#   # bad - imperative with transform and filter
#   results = []
#   items.each do |item|
#     results << item.name if item.active?
#   end
#
#   # good - declarative
#   results = items.select(&:active?).map(&:name)
#   # or with filter_map
#   results = items.filter_map { it.name if it.active? }
#
class RuboCop::Cop::Callbacksystems::PreferDeclarativeCollections < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Prefer declarative collection methods (map, select, filter_map) over imperative `each` with `<<`."

  def on_block(node)
    add_offense(node.send_node.loc.selector, message: MESSAGE) if ImperativeEachBlock.new(node).offense?
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class ImperativeEachBlock
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        each_block? && imperative_pattern?
      end

      private
        attr_reader :node

        def each_block?
          node.method?(:each) && node.receiver
        end

        def imperative_pattern?
          assignment = empty_array_assignment
          assignment && contains_push_to?(node.body, assignment.name)
        end

        def empty_array_assignment
          node.parent&.begin_type? && preceding_assignment
        end

        def preceding_assignment
          siblings = node.parent.children
          siblings[0...siblings.index(node)].rfind { empty_assignment?(it) }
        end

        def empty_assignment?(sibling)
          sibling&.type?(:lvasgn, :ivasgn) && sibling.expression&.array_type? && sibling.expression.children.empty?
        end

        def contains_push_to?(target_node, variable_name)
          case target_node.type
          when :send
            push_to_variable?(target_node, variable_name)
          when :if, :case, :begin
            target_node.each_child_node.any? { contains_push_to?(it, variable_name) }
          else
            false
          end
        end

        def push_to_variable?(send_node, variable_name)
          send_node.method?(:<<) && reads_variable?(send_node.receiver, variable_name)
        end
    end
end
