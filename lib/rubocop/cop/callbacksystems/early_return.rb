# Prohibits early exits except for a single guard clause on the first line.
# Applies to `return` in methods and `next`/`break` in blocks. A body that exits
# in several places has to be read with every exit in mind, and the guard at the
# top is the one shape a reader takes in at a glance. Past it, a condition reads
# better as a branch wrapping what it guards.
#
# @example
#   # bad - return in the middle of method
#   def process(user)
#     data = fetch_data
#     return if data.empty?
#     process_data(data)
#   end
#
#   # bad - multiple early returns
#   def process(user)
#     return unless user
#     return if user.inactive?
#     do_something
#   end
#
#   # bad - next in the middle of a block
#   items.each do |item|
#     process(item)
#     next if item.done?
#     finalize(item)
#   end
#
#   # bad - break in the middle of a block
#   items.each do |item|
#     process(item)
#     break if item.last?
#   end
#
#   # good - single guard clause on first line
#   def process(user)
#     return unless user
#     do_something(user)
#   end
#
#   # good - single next guard on first line
#   items.each do |item|
#     next if item.nil?
#     process(item)
#   end
#
class RuboCop::Cop::Callbacksystems::EarlyReturn < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report_each IllegalExits.new(node.body, :return) if node.body
  end

  alias on_defs on_def

  def on_block(node)
    return if loop_block?(node) || !node.body

    %i[ next break ].each { report_each IllegalExits.new(node.body, it) }
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    # The exits a body takes past the single guard clause it is allowed.
    class IllegalExits
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Avoid early returns. Only a single guard clause on the first line is allowed."
      BLOCK_MESSAGE = "Avoid early next/break. Only a single guard clause on the first line is allowed."

      def initialize(body, exit_type)
        @body = body
        @exit_type = exit_type
      end

      def each_offense
        exits.each { yield RuboCop::Callbacksystems::Offense.new(it, message) }
      end

      private
        attr_reader :body, :exit_type

        def exits
          BodyExits.new(body, exit_type, walk_blocks: returning?)
            .reject { it.equal?(allowed_exit) || handled_by_each_search?(it) }
        end

        # A method's `return` leaves the blocks written inside it, while a block's `next` or `break` stays in its own.
        def returning?
          exit_type == :return
        end

        def allowed_exit
          @allowed_exit ||= Guard.new(body, exit_type).allowed_exit
        end

        def handled_by_each_search?(exit)
          returning? && exit.each_ancestor(:any_block).any? do |block|
            block.method?(:each) && block.body&.source_range&.contains?(exit.source_range) &&
              conditional_return_of_block_argument?(exit, block: block)
          end
        end

        def message
          returning? ? MESSAGE : BLOCK_MESSAGE
        end
    end

    # The exits of one node, gathered branch by branch through the nodes written inside it.
    class BodyExits
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, target_type, walk_blocks:)
        @node = node
        @target_type = target_type
        @walk_blocks = walk_blocks
      end

      def each
        if block_given?
          @pending = [ node ].compact
          until pending.empty?
            advance
            visit { yield it }
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node, :target_type, :walk_blocks, :pending, :current

        def advance
          @current = pending.pop
        end

        def visit
          if current.type == target_type
            yield current
          else
            pending.concat(children_to_walk.reverse)
          end
        end

        def children_to_walk
          if any_block_type?(current)
            block_children
          elsif lexical_definition?(current)
            immediate_inputs_of(current)
          elsif nested_iteration?
            nested_iteration_inputs
          else
            current.each_child_node.to_a
          end
        end

        # A block's receiver and arguments run in the surrounding scope even when its body is a deferred callable.
        def block_children
          immediate_inputs_of(current) + walked_block_body
        end

        def walked_block_body
          walkable_block? ? [ current.body ] : []
        end

        def walkable_block?
          walk_blocks && !deferred_callable_block?(current) && !method_definition_block?(current) &&
            !loop_block?(current) && current.body
        end

        # A `next` or `break` inside a language loop belongs to that loop rather than the surrounding block.
        def nested_iteration?
          !walk_blocks && current.type?(:while, :while_post, :until, :until_post, :for)
        end

        # A `for` collection runs before that loop owns `next` and `break`; its body runs after.
        def nested_iteration_inputs
          current.for_type? ? [ current.collection ] : []
        end
    end

    class Guard
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, exit_type)
        @body = body
        @exit_type = exit_type
      end

      def allowed_exit
        if_guard || unless_guard if first_statement&.if_type?
      end

      private
        attr_reader :body, :exit_type

        def first_statement
          @first_statement ||= first_statement_in(body)
        end

        def if_guard
          first_statement.if_branch if exit?(first_statement.if_branch) && first_statement.else_branch.nil?
        end

        def exit?(branch)
          branch&.type == exit_type
        end

        def unless_guard
          first_statement.else_branch if exit?(first_statement.else_branch) && first_statement.if_branch.nil?
        end
    end
end
