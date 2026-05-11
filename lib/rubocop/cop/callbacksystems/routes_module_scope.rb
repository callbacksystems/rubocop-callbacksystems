# Ensures repeated `module:` options in routes are extracted to a scope block.
#
# @example
#   # bad - module: repeated multiple times
#   resources :users, module: :admin
#   resources :posts, module: :admin
#   resources :comments, module: :admin
#
#   # good - use scope block
#   scope module: :admin do
#     resources :users
#     resources :posts
#     resources :comments
#   end
#
class RuboCop::Cop::Callbacksystems::RoutesModuleScope < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Extract repeated `module: %<module>s` to a `scope module: %<module>s do` block."
  ROUTE_METHODS = %i[resources resource get post put patch delete match root].freeze

  def on_new_investigation
    return unless routes_file?

    grouped_routes.each do |(_parent, module_value), routes|
      next unless routes.many?

      routes.each do |route|
        add_offense(route[:node], message: format(MESSAGE, module: module_value))
      end
    end
  end

  private
    def routes_file?
      path = processed_source.file_path
      path && (path.include?("config/routes") || path.end_with?("routes.rb"))
    end

    def grouped_routes
      routes_with_module.group_by { [ it[:parent_block], it[:module_value] ] }
    end

    def routes_with_module
      return [] unless processed_source.ast

      processed_source.ast.each_node(:send).filter_map do |node|
        next if ROUTE_METHODS.exclude?(node.method_name)

        route = RouteNode.new(node)
        { node: node, module_value: route.module_value, parent_block: route.parent_block } if route.module_value
      end
    end

    class RouteNode
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def module_value
        @module_value ||= find_module_pair&.then do |pair|
          pair.value.respond_to?(:value) ? pair.value.value.to_s : pair.value.source
        end
      end

      def parent_block
        node.each_ancestor(:block).first || :root
      end

      private
        def find_module_pair
          node.arguments.select(&:hash_type?).flat_map(&:pairs).find { it.key.value == :module }
        end
    end
end
