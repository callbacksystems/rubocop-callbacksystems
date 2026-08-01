# Ensures repeated `module:` options in routes are extracted to a scope block.
#
# Autocorrection consolidates the routes only when they are contiguous, so it
# never reorders a route past another and changes matching precedence.
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
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Extract repeated `module: %<module>s` to a `scope module: %<module>s do` block."
  ROUTE_METHODS = %i[resources resource get post put patch delete match root].freeze

  def on_new_investigation
    repeated_route_groups.each_value { register(it) } if routes_file?(processed_source.file_path)
  end

  private
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

    def register(routes)
      consolidation = Consolidation.new(processed_source, routes)
      routes.each_with_index do |route, index|
        message = format(MESSAGE, module: route.module_value)
        if index.zero? && consolidation.applicable?
          add_offense(route.node, message: message) { consolidation.rewrite(it) }
        else
          add_offense(route.node, message: message)
        end
      end
    end

    # Rewrites a contiguous run of routes that share a `module:` into a single
    # `scope module: ... do` block, dropping the now-redundant option from each.
    class Consolidation
      include RuboCop::Cop::RangeHelp

      def initialize(processed_source, routes)
        @processed_source = processed_source
        @routes = routes
      end

      def applicable?
        contiguous? && !comments_within_span?
      end

      def rewrite(corrector)
        corrector.replace(span, scope_block)
      end

      private
        attr_reader :processed_source, :routes

        def contiguous?
          container = nodes.first.parent
          container&.begin_type? &&
            nodes.all? { it.parent.equal?(container) } &&
            consecutive?(nodes.map { container.children.index(it) })
        end

        def nodes
          @nodes ||= routes.map(&:node)
        end

        def consecutive?(indexes)
          indexes.sort.each_cons(2).all? { |left, right| right == left + 1 }
        end

        def comments_within_span?
          processed_source.comments.any? { it.loc.line.between?(first_node.first_line, last_node.last_line) }
        end

        def first_node
          ordered_nodes.first
        end

        def ordered_nodes
          @ordered_nodes ||= nodes.sort_by { it.source_range.begin_pos }
        end

        def last_node
          ordered_nodes.last
        end

        def span
          range_between(first_node.source_range.begin_pos, last_node.source_range.end_pos)
        end

        def scope_block
          [ "scope module: #{module_source} do", *route_lines, "#{indent}end" ].join("\n")
        end

        def module_source
          routes.first.module_value
        end

        def route_lines
          ordered_nodes.map { "#{indent}  #{route_without_module(it)}" }
        end

        def indent
          @indent ||= " " * first_node.source_range.column
        end

        def route_without_module(node)
          full = node.source_range
          gap = module_removal_range(node)
          range_between(full.begin_pos, gap.begin_pos).source + range_between(gap.end_pos, full.end_pos).source
        end

        def module_removal_range(node)
          elements = argument_elements(node)
          index = elements.index { module_pair?(it) }
          if index < elements.size - 1
            range_between(elements[index].source_range.begin_pos, elements[index + 1].source_range.begin_pos)
          else
            range_between(elements[index - 1].source_range.end_pos, elements[index].source_range.end_pos)
          end
        end

        def argument_elements(node)
          node.arguments.flat_map { it.hash_type? ? it.pairs : [ it ] }
        end

        def module_pair?(element)
          element.pair_type? && element.key.value == :module
        end
    end

    class RouteNode
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def group_key
        [ parent_block, normalized_module ]
      end

      def module_value
        module_pair&.value&.source
      end

      private
        def parent_block
          node.each_ancestor(:block).first || :root
        end

        def normalized_module
          @normalized_module ||= module_pair&.value&.then do |value|
            value.type?(:sym, :str) ? value.value.to_s : value.source
          end
        end

        def module_pair
          node.arguments.select(&:hash_type?).flat_map(&:pairs).find { it.key.value == :module }
        end
    end
end
