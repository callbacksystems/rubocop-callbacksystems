# Prohibits early exits except for a single guard clause on the first line. Applies to `return` in methods and
# `next`/`break` in blocks.
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
  MESSAGE = "Avoid early returns. Only a single guard clause on the first line is allowed."
  BLOCK_MESSAGE = "Avoid early next/break. Only a single guard clause on the first line is allowed."

  def on_def(node)
    if node.body
      illegal_exits(node.body, :return, walk_blocks: true).each { add_offense(it, message: MESSAGE) }
    end
  end

  alias on_defs on_def

  def on_block(node)
    return if loop_block?(node) || !node.body

    %i[next break].each do |type|
      illegal_exits(node.body, type, walk_blocks: false).each { add_offense(it, message: BLOCK_MESSAGE) }
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def illegal_exits(body, type, walk_blocks:)
      allowed = Guard.new(body, type).allowed_exit
      ExitFinder.new(body, type, walk_blocks: walk_blocks).exits.reject { it.equal?(allowed) }
    end

    def loop_block?(node)
      node.method?(:loop)
    end

    class Guard
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, exit_type)
        @body = body
        @exit_type = exit_type
      end

      def allowed_exit
        stmt = first_statement_in(body)
        stmt&.if_type? && allowed_from_if(stmt)
      end

      private
        attr_reader :body, :exit_type

        def allowed_from_if(if_node)
          if_guard(if_node) || unless_guard(if_node)
        end

        def if_guard(if_node)
          if_node.if_branch if if_node.if_branch&.type == exit_type && if_node.else_branch.nil?
        end

        def unless_guard(if_node)
          if_node.else_branch if if_node.else_branch&.type == exit_type && if_node.if_branch.nil?
        end
    end

    class ExitFinder
      block_statements = ->(node, finder) { node.children.flat_map { finder.call(it) } }

      FINDERS = {
        if: ->(node, finder) { finder.call(node.if_branch) + finder.call(node.else_branch) },
        begin: block_statements,
        kwbegin: block_statements,
        case: ->(node, finder) do
          node.when_branches.flat_map { finder.call(it.body) } + finder.call(node.else_branch)
        end,
        case_match: ->(node, finder) do
          node.each_child_node(:in_pattern).flat_map { finder.call(it.body) } + finder.call(node.else_branch)
        end,
        in_pattern: ->(node, finder) { finder.call(node.body) },
        rescue: ->(node, finder) do
          finder.call(node.body) + node.resbody_branches.flat_map { finder.call(it.body) } + finder.call(node.else_branch)
        end,
        resbody: ->(node, finder) { finder.call(node.body) },
        when: ->(node, finder) { finder.call(node.body) },
        ensure: ->(node, finder) { finder.call(node.branch) }
      }.freeze

      def initialize(node, target_type, walk_blocks:)
        @node = node
        @target_type = target_type
        @walk_blocks = walk_blocks
      end

      def exits(current = node)
        if current
          if current.type == target_type
            [ current ]
          elsif current.type?(:any_block)
            walk_block(current)
          else
            FINDERS.fetch(current.type, ->(_, _) { [] }).call(current, method(:exits))
          end
        else
          []
        end
      end

      private
        attr_reader :node, :target_type, :walk_blocks

        def walk_block(current)
          walkable_block?(current) ? exits(current.body) : []
        end

        def walkable_block?(current)
          walk_blocks && !current.lambda? && !loop_block?(current) && current.body
        end

        def loop_block?(node)
          node.method?(:loop)
        end
    end
end
