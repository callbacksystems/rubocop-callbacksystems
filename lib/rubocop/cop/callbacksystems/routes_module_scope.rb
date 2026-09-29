# Ensures a `module:` option repeated across routes is extracted to a `scope`
# block. Repeated, the namespace sits on every line and a reader compares them
# to learn that the routes share a controller directory, where one
# `scope module:` says it once and lets the routes read bare.
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

  def on_new_investigation
    if routes_file?(processed_source.file_path)
      @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
      @statement_positions = StatementPositions.new
      repeated_route_groups.each { report_each RouteGroup.new(it, source_comments:, statement_positions:) }
    end
  end

  private
    ROUTE_METHODS = %i[ resources resource get post put patch delete match root ]

    attr_reader :source_comments, :statement_positions

    def repeated_route_groups
      routes_with_module.group_by(&:group_key).values.select(&:many?)
    end

    def routes_with_module
      route_calls.map { Route.new(it) }.select(&:module_value)
    end

    def route_calls
      RuboCop::Callbacksystems::Execution::Immediate.new(processed_source.ast).nodes_of_type(:send)
        .select { bare_send?(it) && ROUTE_METHODS.include?(it.method_name) }
    end

    # Routes repeating one `module:`, where only the first offense carries the correction that rewrites the whole run.
    class RouteGroup
      MESSAGE = "Extract repeated `module: %<module>s` to a `scope module: %<module>s do` block."

      def initialize(routes, source_comments:, statement_positions:)
        @routes = routes
        @source_comments = source_comments
        @statement_positions = statement_positions
      end

      def each_offense
        yield offense_for(routes.first, correcting: consolidation.applicable?)
        routes.drop(1).each { yield offense_for(it, correcting: false) }
      end

      private
        attr_reader :routes, :source_comments, :statement_positions

        def offense_for(route, correcting:)
          RuboCop::Callbacksystems::Offense.new(route.node, message_for(route), correcting:) { consolidation.rewrite(it) }
        end

        def message_for(route)
          format(MESSAGE, module: route.module_value)
        end

        def consolidation
          @consolidation ||= Consolidation.new(routes, source_comments:, statement_positions:)
        end
    end

    # One group of routes rewritten as a `scope module:` block, when they sit together with no comment among them.
    class Consolidation
      include RuboCop::Callbacksystems::Helpers

      def initialize(routes, source_comments:, statement_positions:)
        @routes = routes
        @source_comments = source_comments
        @statement_positions = statement_positions
      end

      def applicable?
        contiguous? && routes.all?(&:literal_module?) && routes.all?(&:module_removable?) && source_self_contained? &&
          !comments_within_span?
      end

      def rewrite(corrector)
        corrector.replace(span, scope_block)
      end

      private
        attr_reader :routes, :source_comments, :statement_positions

        def contiguous?
          container.begin_type? && nodes.all? { it.parent.equal?(container) } && consecutive?(positions_in_container)
        end

        def container
          @container ||= nodes.first.parent
        end

        def nodes
          @nodes ||= routes.map(&:node)
        end

        def consecutive?(indexes)
          indexes.sort.each_cons(2).all? { |left, right| right == left + 1 }
        end

        def positions_in_container
          nodes.map { statement_positions.position_of(it) }
        end

        def source_self_contained?
          routes.none? { carries_heredoc?(it.node) }
        end

        def comments_within_span?
          source_comments.any_on_lines?(span.first_line..span.last_line)
        end

        def span
          @span ||= range_spanning(ordered_routes.map(&:node))
        end

        def ordered_routes
          @ordered_routes ||= routes.sort_by { it.node.source_range.begin_pos }
        end

        def scope_block
          [ "scope module: #{module_source} do", *route_lines, "#{indent}end" ].join("\n")
        end

        def module_source
          routes.first.module_value
        end

        def route_lines
          ordered_routes.map { "#{indent}  #{it.source_without_module}" }
        end

        def indent
          @indent ||= indentation_of(ordered_routes.first.node)
        end
    end

    # Statement positions shared by route groups, preserving node identity when two routes have identical syntax.
    class StatementPositions
      def initialize
        @by_container = {}.compare_by_identity
      end

      def position_of(node)
        positions_in(node.parent).fetch(node)
      end

      private
        attr_reader :by_container

        def positions_in(container)
          by_container[container] ||= positions_of(container.children)
        end

        def positions_of(statements)
          statements.each_with_index.with_object({}.compare_by_identity) do |(statement, position), positions|
            positions[statement] = position
          end
        end
    end

    class Route
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def group_key
        [ parent_block, normalized_module ]
      end

      def module_value
        module_node&.source
      end

      def literal_module?
        module_node.type?(:sym, :str)
      end

      def module_removable?
        module_pairs.one?
      end

      def source_without_module
        before_module.source + after_module.source
      end

      private
        # Two blocks written alike compare equal as nodes, so the position tells the parents apart.
        def parent_block
          node.each_ancestor(*BLOCK_NODE_TYPES).first&.then { it.source_range.begin_pos } || :root
        end

        def normalized_module
          [ module_node.type, literal_name_of(module_node) ]
        end

        def module_node
          module_pair&.value
        end

        def module_pair
          keyword_options.option_for(:module)
        end

        def keyword_options
          @keyword_options ||= RuboCop::Callbacksystems::Hashes::KeywordOptions.new(*node.arguments.select(&:hash_type?))
        end

        def module_pairs
          keyword_options.explicit_options_for(:module)
        end

        def before_module
          node.source_range.with(end_pos: module_gap.begin_pos)
        end

        def module_gap
          explicit_options? ? explicit_module_gap : implicit_module_gap
        end

        def explicit_options?
          options.loc.begin
        end

        def options
          module_pair.parent
        end

        def explicit_module_gap
          if option_after_module
            module_pair.source_range.with(end_pos: option_after_module.source_range.begin_pos)
          elsif option_before_module
            option_before_module.source_range.end.join(module_pair.source_range.end)
          else
            options_argument_gap
          end
        end

        def option_after_module
          option_elements[option_index + 1]
        end

        def option_elements
          options.children
        end

        def option_index
          option_elements.index { it.equal?(module_pair) }
        end

        def option_before_module
          option_elements[option_index - 1] if option_index.positive?
        end

        def options_argument_gap
          following_options_gap || preceding_options_gap || sole_options_gap
        end

        def following_options_gap
          argument_after_options&.then { options.source_range.with(end_pos: it.source_range.begin_pos) }
        end

        def argument_after_options
          node.arguments[options_index + 1]
        end

        def options_index
          node.arguments.index { it.equal?(options) }
        end

        def preceding_options_gap
          argument_before_options&.then { it.source_range.end.join(options.source_range.end) }
        end

        def argument_before_options
          node.arguments[options_index - 1] if options_index.positive?
        end

        def sole_options_gap
          node.loc.begin.join(node.loc.end)
        end

        def implicit_module_gap
          if element_after_module
            module_pair.source_range.join(element_after_module.source_range.begin)
          elsif element_before_module
            element_before_module.source_range.end.join(module_pair.source_range)
          else
            node.loc.selector.end.join(node.source_range.end)
          end
        end

        def element_after_module
          elements[module_index + 1]
        end

        def elements
          @elements ||= node.arguments.flat_map { it.hash_type? ? it.children : [ it ] }
        end

        def module_index
          elements.index { it.equal?(module_pair) }
        end

        def element_before_module
          elements[module_index - 1] if module_index.positive?
        end

        def after_module
          node.source_range.with(begin_pos: module_gap.end_pos)
        end
    end
end
