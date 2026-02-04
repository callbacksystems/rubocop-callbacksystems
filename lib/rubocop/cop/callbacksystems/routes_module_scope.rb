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
class RuboCop::Cop::Callbacksystems::RoutesModuleScope < RuboCop::Cop::Base
  ROUTE_METHODS = %i[resources resource get post put patch delete match root].freeze

  # Finds route calls with module: option
  def_node_search :route_calls_with_module, <<~PATTERN
    (send nil? {#{ROUTE_METHODS.map(&:inspect).join(" ")}} ... (hash <(pair (sym :module) $_) ...>))
  PATTERN

  def on_new_investigation
    return unless routes_file?

    grouped_routes.each do |(_parent, module_value), routes|
      next unless routes.many?

      routes.each do |route|
        add_offense(route[:node], message: "Extract repeated `module: #{module_value}` to a `scope module: #{module_value} do` block.")
      end
    end
  end

  private
    def routes_file?
      path = processed_source.file_path
      path && (path.include?("config/routes") || path.end_with?("routes.rb"))
    end

    def grouped_routes
      routes_with_module.group_by { |route| [ RouteNode.new(route[:node]).parent_block, route[:module_value] ] }
    end

    def routes_with_module
      return [] unless processed_source.ast

      processed_source.ast.each_node(:send).filter_map do |node|
        next unless ROUTE_METHODS.include?(node.method_name)

        module_value = RouteNode.new(node).module_value
        { node: node, module_value: module_value } if module_value
      end
    end

    class RouteNode
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def module_value
        find_module_pair&.then do |pair|
          pair.value.respond_to?(:value) ? pair.value.value.to_s : pair.value.source
        end
      end

      def parent_block
        node.each_ancestor(:block).first || :root
      end

      private
        def find_module_pair
          node.arguments.select(&:hash_type?).flat_map(&:pairs).find { |p| p.key.value == :module }
        end
    end
end
