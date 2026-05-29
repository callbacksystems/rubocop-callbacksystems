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
    each_offense { |node, message| add_offense(node, message: message) }
  end

  private
    def each_offense(&block)
      if block
        yield_route_offenses(&block) if routes_file?
      else
        to_enum(__method__)
      end
    end

    def routes_file?
      path = processed_source.file_path
      path && (path.include?("config/routes") || path.end_with?("routes.rb"))
    end

    def yield_route_offenses(&block)
      repeated_route_groups.each_value do |routes|
        routes.each { yield it.node, format(MESSAGE, module: it.module_value) }
      end
    end

    def repeated_route_groups
      grouped_routes.select { |_, routes| routes.many? }
    end

    def grouped_routes
      routes_with_module.group_by(&:group_key)
    end

    def routes_with_module
      if processed_source.ast
        processed_source.ast.each_node(:send).filter_map do |node|
          next if ROUTE_METHODS.exclude?(node.method_name)

          route = RouteNode.new(node)
          route if route.module_value
        end
      else
        []
      end
    end

    class RouteNode
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def group_key
        [ parent_block, module_value ]
      end

      def module_value
        @module_value ||= module_pair&.value&.then do |value|
          value.type?(:sym, :str) ? value.value.to_s : value.source
        end
      end

      private
        def parent_block
          node.each_ancestor(:block).first || :root
        end

        def module_pair
          node.arguments.select(&:hash_type?).flat_map(&:pairs).find { it.key.value == :module }
        end
    end
end
