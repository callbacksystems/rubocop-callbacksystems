# Prohibits early returns except for a single guard clause on the first line.
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
#   # good - single guard clause on first line
#   def process(user)
#     return unless user
#     do_something(user)
#   end
#
#   # good - no early returns
#   def process(user)
#     if user
#       do_something(user)
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::EarlyReturn < RuboCop::Cop::Base
  MESSAGE = "Avoid early returns. Only a single guard clause on the first line is allowed."
  IGNORE_TYPES = %i[block numblock].freeze

  def on_def(node)
    return unless node.body

    illegal_returns(node).each { |return_node| add_offense(return_node, message: MESSAGE) }
  end

  alias on_defs on_def

  private
    def illegal_returns(method_node)
      all_returns = Returns.new(method_node.body).find_all
      allowed = Guard.new(method_node.body).allowed_return
      all_returns.reject { |r| r.equal?(allowed) }
    end

    class Guard
      include RuboCop::Callbacksystems::Helpers

      attr_reader :body

      def initialize(body)
        @body = body
      end

      def allowed_return
        first_stmt = first_statement(body)
        first_stmt&.if_type? && IfGuard.new(first_stmt).allowed_return
      end
    end

    class IfGuard
      attr_reader :if_node

      def initialize(if_node)
        @if_node = if_node
      end

      def allowed_return
        return_if_guard || return_unless_guard
      end

      private
        def return_if_guard
          if_node.if_branch if if_node.if_branch&.return_type? && if_node.else_branch.nil?
        end

        def return_unless_guard
          if_node.else_branch if if_node.else_branch&.return_type? && if_node.if_branch.nil?
        end
    end

    class Returns
      IGNORE_TYPES = %i[block numblock].freeze

      FINDERS = {
        return: ->(node, _finder) { [ node ] },
        if: ->(node, finder) { finder.call(node.if_branch) + finder.call(node.else_branch) },
        begin: ->(node, finder) { node.children.flat_map { |c| finder.call(c) } },
        kwbegin: ->(node, finder) { node.children.flat_map { |c| finder.call(c) } },
        case: ->(node, finder) { node.when_branches.flat_map { |b| finder.call(b.body) } + finder.call(node.else_branch) },
        rescue: ->(node, finder) { finder.call(node.body) + node.resbody_branches.flat_map { |b| finder.call(b.body) } + (node.else_branch ? finder.call(node.else_branch) : []) },
        resbody: ->(node, finder) { finder.call(node.body) },
        when: ->(node, finder) { finder.call(node.body) },
        ensure: ->(node, finder) { finder.call(node.branch) }
      }.freeze

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def find_all(node = self.node)
        return [] unless node && !IGNORE_TYPES.include?(node.type)

        FINDERS.fetch(node.type, ->(_, _) { [] }).call(node, method(:find_all))
      end
    end
end
