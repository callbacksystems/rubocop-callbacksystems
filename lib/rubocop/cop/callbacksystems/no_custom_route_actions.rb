# Keeps routes on the standard resource actions. A custom action is a verb
# bolted onto a controller, and the noun it acts on is a resource of its own
# waiting to be named, so `confirm` on messages becomes a `confirmation`
# resource with a `create` action and the controller stays one noun with the
# seven actions a reader expects.
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
  def on_new_investigation
    @immediate_nodes = {}.compare_by_identity
    RuboCop::Callbacksystems::Execution::Immediate.new(processed_source.ast).each { @immediate_nodes[it] = true }
  end

  def on_block(node)
    report ScopeBlock.new(node) if in_routes_file? && immediately_executed?(node)
  end
  alias on_numblock on_block
  alias on_itblock on_block

  def on_send(node)
    report VerbRoute.new(node) if in_routes_file? && immediately_executed?(node)
  end
  alias on_csend on_send

  private
    CUSTOM_SCOPES = %i[ member collection new ]

    def in_routes_file?
      routes_file?(processed_source.file_path)
    end

    def immediately_executed?(node)
      @immediate_nodes.key?(node)
    end

    class ScopeBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Custom actions belong to their own resource. Replace the `%<scope>s` block with nested resources."

      def initialize(node)
        @node = node
      end

      def offense
        if scoped_block?
          RuboCop::Callbacksystems::Offense.new(node.send_node, format(MESSAGE, scope: node.method_name))
        end
      end

      private
        attr_reader :node

        def scoped_block?
          CUSTOM_SCOPES.include?(node.method_name) && bare_send?(node.send_node) &&
            node.send_node.arguments.empty? && inside_resources?
        end

        def inside_resources?
          node.each_ancestor(*BLOCK_NODE_TYPES).any? do |block|
            bare_send?(block.send_node) && %i[ resources resource ].include?(block.method_name)
          end
        end
    end

    class VerbRoute
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Custom actions belong to their own resource. Route `%<action>s` as a resource instead of `on: " \
        ":%<scope>s`."
      ROUTE_VERBS = %i[ get post patch put delete match ]

      def initialize(node)
        @node = node
      end

      def offense
        if scoped_route?
          RuboCop::Callbacksystems::Offense.new(node, format(MESSAGE, action: action_name, scope: custom_scope))
        end
      end

      private
        attr_reader :node
        delegate :first_argument, to: :node, private: true

        def scoped_route?
          ROUTE_VERBS.include?(node.method_name) && bare_send?(node) && custom_scope.present?
        end

        def custom_scope
          @custom_scope ||= on_option_value&.then { it.value if it.sym_type? && CUSTOM_SCOPES.include?(it.value) }
        end

        def on_option_value
          keyword_options.option_for(:on)&.value
        end

        def keyword_options
          @keyword_options ||= RuboCop::Callbacksystems::Hashes::KeywordOptions.new(*node.arguments.select(&:hash_type?))
        end

        def action_name
          literal_name_of(first_argument)
        end
    end
end
