# Keeps routes on the standard resource actions, so a custom action becomes
# its own resource instead of a member or collection addition.
#
# @example
#   # bad - custom action through an option
#   resources :messages do
#     post :confirm, on: :member
#   end
#
#   # bad - custom actions through a block
#   resources :messages do
#     member do
#       post :confirm
#     end
#   end
#
#   # good - the action becomes a resource
#   resources :messages do
#     resource :confirmation, only: :create
#   end
#
class RuboCop::Cop::Callbacksystems::NoCustomRouteActions < RuboCop::Cop::Callbacksystems::Base
  BLOCK_MESSAGE = "Custom actions belong to their own resource. Replace the `%<scope>s` block with nested resources."
  OPTION_MESSAGE = "Custom actions belong to their own resource. Route `%<action>s` as a resource instead of `on: :%<scope>s`."
  CUSTOM_SCOPES = %i[member collection new].freeze

  def on_block(node)
    scope_block = ScopeBlock.new(node)
    add_offense(node.send_node, message: scope_block.offense_message) if in_routes_file? && scope_block.offense?
  end
  alias on_numblock on_block

  def on_send(node)
    route = VerbRoute.new(node)
    add_offense(node, message: route.offense_message) if in_routes_file? && route.offense?
  end
  alias on_csend on_send

  private
    def in_routes_file?
      routes_file?(processed_source.file_path)
    end

    class ScopeBlock
      def initialize(node)
        @node = node
      end

      def offense?
        CUSTOM_SCOPES.include?(node.method_name) && node.receiver.nil? &&
          node.send_node.arguments.empty? && inside_resources?
      end

      def offense_message
        format(BLOCK_MESSAGE, scope: node.method_name)
      end

      private
        attr_reader :node

        def inside_resources?
          node.each_ancestor(:block).any? { %i[resources resource].include?(it.method_name) }
        end
    end

    class VerbRoute
      ROUTE_VERBS = %i[get post patch put delete match].freeze

      def initialize(node)
        @node = node
      end

      def offense?
        ROUTE_VERBS.include?(node.method_name) && node.receiver.nil? && custom_scope.present?
      end

      def offense_message
        format(OPTION_MESSAGE, action: action_name, scope: custom_scope)
      end

      private
        attr_reader :node

        def custom_scope
          @custom_scope ||= on_option_value&.then { it.value if it.sym_type? && CUSTOM_SCOPES.include?(it.value) }
        end

        def on_option_value
          node.arguments.select(&:hash_type?).flat_map(&:pairs).find { it.key.value == :on }&.value
        end

        def action_name
          argument = node.first_argument
          argument.type?(:sym, :str) ? argument.value : argument.source
        end
    end
end
