# Ensures eager loading scopes follow naming conventions. A scope named for the
# associations it loads (`with_posts`) reads at the call site as what the query
# carries, while one named for the page that uses it (`with_show_data`) ties the
# model to a controller, and one named for a generic term (`with_associations`)
# says nothing about what gets loaded.
# The `with_*` prefix is reserved for eager loading. A scope whose body only
# filters or orders records needs a name describing that condition instead.
# Composed scopes and dynamic query builders stay out when their eager loading
# cannot be determined from the body.
# Default scopes may come from ancestors or concerns; unreadable ancestry leaves
# the reverse naming check undecided while explicit eager loading is still read.
# - Must use `with_*` prefix for any of includes, preload, or eager_load
# - Must not contain controller action names (index, show, etc.)
# - Must not contain generic terms (associations, relations)
#
# @example
#   # bad - missing with_ prefix
#   scope :including_posts, -> { includes(:posts) }
#
#   # bad - contains controller action
#   scope :with_show_data, -> { includes(:items) }
#
#   # bad - contains generic term
#   scope :with_associations, -> { includes(:items) }
#
#   # bad - with_ promises eager loading, not a filter
#   scope :with_active, -> { where(active: true) }
#
#   # good
#   scope :with_posts, -> { includes(:posts) }
#   scope :with_line_items, -> { includes(:line_items) }
#   scope :active, -> { where(active: true) }
#
class RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support

  def on_new_investigation
    @default_scopes = if project_index.nil? || project_index_reliable?
      DefaultScopes.new(processed_source, project_index:)
    end
  end

  def on_send(node)
    report ScopeName.new(node, default_scopes:) if scope_definition?(node)
  end

  alias on_csend on_send

  private
    attr_reader :default_scopes

    # The name a `scope` declares, read against the association its body eager loads.
    class ScopeName
      include RuboCop::Callbacksystems::Helpers

      PREFIX_MESSAGE = "Eager loading scopes should follow `with_*` convention. Rename `%<name>s` to " \
        "`with_%<association>s`."
      ACTION_MESSAGE = "Scope name `%<name>s` contains controller action `%<action>s`. Use a more descriptive name."
      GENERIC_MESSAGE = "Scope name `%<name>s` contains generic term `%<term>s`. Use a more specific name like " \
        "`with_%<association>s`."
      RESERVED_PREFIX_MESSAGE = "Reserve `with_*` for eager loading scopes. Rename `%<name>s` to describe its query."
      GENERIC_TERMS = %w[ association associations relation relations ]

      def initialize(node, default_scopes:)
        @node = node
        @default_scopes = default_scopes
      end

      def offense
        if messages.any?
          RuboCop::Callbacksystems::Offense.new(node.first_argument, messages.join(" "))
        end
      end

      private
        attr_reader :node, :default_scopes

        def messages
          if association
            [ prefix_message, action_message, generic_message ].compact
          elsif name.start_with?("with_") && scope_body.without_eager_loading?
            [ format(RESERVED_PREFIX_MESSAGE, name:) ]
          else
            []
          end
        end

        def association
          @association ||= scope_body.eager_loading_association
        end

        def scope_body
          @scope_body ||= ScopeBody.new(node.arguments.second, default_scopes:)
        end

        def prefix_message
          format(PREFIX_MESSAGE, name:, association:) unless name.start_with?("with_")
        end

        def name
          node.first_argument.value.to_s
        end

        def action_message
          format(ACTION_MESSAGE, name:, action: controller_action) if controller_action
        end

        def controller_action
          STANDARD_CONTROLLER_ACTIONS.find { name_parts.include?(it.to_s) }
        end

        def name_parts
          @name_parts ||= name.split("_")
        end

        def generic_message
          format(GENERIC_MESSAGE, name:, term: generic_term, association:) if generic_term
        end

        def generic_term
          GENERIC_TERMS.find { name_parts.include?(it) }
        end
    end

    class ScopeBody
      include RuboCop::Callbacksystems::Helpers

      QUERY_METHODS = %i[
        all distinct group having invert_where joins left_joins left_outer_joins limit none offset order
        readonly references reorder reselect reverse_order rewhere select strict_loading unscope where
      ]

      def initialize(body, default_scopes:)
        @body = body
        @default_scopes = default_scopes
      end

      def eager_loading_association
        association_name_for(eager_load_call) if eager_load_call
      end

      def without_eager_loading?
        deferred_callable_block?(body) && eager_load_call.nil? && !default_scope? && plain_query?(scope_body.body)
      end

      private
        attr_reader :body, :default_scopes

        def eager_load_call
          return @eager_load_call if defined?(@eager_load_call)

          @eager_load_call = RuboCop::Callbacksystems::Execution::Immediate.new(scope_body&.body).find do |candidate|
            candidate.call_type? && EAGER_LOADING_METHODS.include?(candidate.method_name)
          end
        end

        def scope_body
          body if any_block_type?(body)
        end

        def association_name_for(eager_load_node)
          names = eager_load_node.arguments.flat_map { AssociationNames.new(it).to_a }
          names.join("_and_") if names.any?
        end

        def default_scope?
          default_scopes.nil? || default_scopes.possible_for?(body)
        end

        # A named scope, a merge, or a dynamic builder can carry eager loading from another declaration.
        def plain_query?(expression)
          expression&.call_type? && query_method?(expression) &&
            (call_on_self?(expression) || plain_query?(expression.receiver))
        end

        def query_method?(expression)
          QUERY_METHODS.include?(expression.method_name) || where_negation?(expression)
        end

        def where_negation?(expression)
          expression.method?(:not) && expression.receiver.call_type? && expression.receiver.method?(:where) &&
            expression.receiver.arguments.empty?
        end
    end

    # Absence is trusted only in readable declarations and their known ancestry; a model's defaults may live elsewhere.
    class DefaultScopes
      include RuboCop::Callbacksystems::Helpers
      include RuboCop::Cop::ProjectIndexHelp

      def initialize(processed_source, project_index:)
        @processed_source = processed_source
        @project_index = project_index
        @sources = {}
        @possibilities = {}.compare_by_identity
      end

      def possible_for?(node)
        owner = enclosing_class_or_module_of(node)

        owner.nil? || node.each_ancestor.take_while { !it.equal?(owner) }.any? { any_block_type?(it) } ||
          possibilities.fetch(owner) { possibilities[owner] = possible_in?(owner) }
      end

      private
        attr_reader :processed_source, :project_index, :sources, :possibilities

        def possible_in?(owner)
          return true if owner.module_type?

          declarations = if project_index
            indexed_declarations_for(owner)
          else
            local_declarations_for(owner)
          end

          declarations.nil? || declarations.any? { it.default_scope? || !it.known_ancestry? }
        end

        def indexed_declarations_for(owner)
          namespace = resolve_constant_in_index(owner.identifier)

          if namespace.is_a?(Rubydex::Namespace) && namespace.definitions.any?
            definitions_for(namespace).map { declaration_for(it) }.then do |declarations|
              declarations.presence if declarations.exclude?(nil)
            end
          end
        end

        def definitions_for(namespace)
          ancestors = [ *namespace.ancestors, *namespace.singleton_class.ancestors ].map do |ancestor|
            ancestor.is_a?(Rubydex::SingletonClass) ? ancestor.attached_class : ancestor
          end

          ancestors.uniq(&:name).flat_map { it.definitions.to_a }.select do |definition|
            definition.location.uri.start_with?(FILE_URI_PREFIX)
          end
        end

        def declaration_for(definition)
          source_for(definition.location)&.declaration_at(definition.location)
        end

        def source_for(location)
          path = location.to_file_path

          sources.fetch(path) do
            source = if File.expand_path(path) == File.expand_path(processed_source.file_path)
              processed_source
            else
              RuboCop::Callbacksystems::Source::FileAst
                .processed_source(path, ruby_version: processed_source.ruby_version)
            end
            sources[path] = Source.new(source, project_index:) if source
          end
        end

        def local_declarations_for(owner)
          candidates = nodes_in(processed_source.ast, :class, :module).select do |candidate|
            candidate.identifier.short_name == owner.identifier.short_name
          end

          candidates.map { Declaration.new(it, project_index:) }
        end

        class Source
          include RuboCop::Callbacksystems::Helpers

          def initialize(processed_source, project_index:)
            @declarations = nodes_in(processed_source.ast, :class, :module).to_h do |node|
              location = RuboCop::Callbacksystems::ProjectIndex::Location.for_ast \
                node.source_range, uri: RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(processed_source.file_path).uri
              [ location, Declaration.new(node, project_index:) ]
            end
          end

          def declaration_at(location)
            declarations[RuboCop::Callbacksystems::ProjectIndex::Location.for_rubydex(location)]
          end

          private
            attr_reader :declarations
        end

        class Declaration
          include RuboCop::Callbacksystems::Helpers

          MIXIN_METHODS = %i[ include prepend extend ]

          def initialize(node, project_index:)
            @node = node
            @project_index = project_index
          end

          def default_scope?
            members.any? do |member|
              member.method?(:default_scope) && (member.any_def_type? || call_on_self?(member))
            end
          end

          def known_ancestry?
            ancestors.all? { Ancestor.new(it, project_index:).known? }
          end

          private
            attr_reader :node, :project_index

            def members
              @members ||= nodes_in(node.body, :send, :csend, :def, :defs).select do |member|
                enclosing_class_or_module_of(member).equal?(node)
              end
            end

            def ancestors
              superclass = node.parent_class if node.class_type?
              mixins = members.select do |member|
                member.call_type? && call_on_self?(member) && MIXIN_METHODS.include?(member.method_name)
              end

              [ superclass, *mixins.flat_map(&:arguments) ].compact
            end
        end

        class Ancestor
          include RuboCop::Callbacksystems::Helpers
          include RuboCop::Cop::ProjectIndexHelp

          FRAMEWORK_ANCESTORS = %w[ ActiveRecord::Base ActiveSupport::Concern ]

          def initialize(node, project_index:)
            @node = node
            @project_index = project_index
          end

          def known?
            framework? || (project_index && node.const_type? &&
              resolve_constant_in_index(node).is_a?(Rubydex::Namespace))
          end

          private
            attr_reader :node, :project_index

            def framework?
              FRAMEWORK_ANCESTORS.include?(constant_name_of(node)&.delete_prefix("::")) &&
                (node.absolute? || lexical_nesting_of(node).empty?)
            end
        end
    end

    class AssociationNames
      include Enumerable

      def initialize(argument)
        @argument = argument
      end

      def each
        if block_given?
          @pending = [ argument ]
          until pending.empty?
            advance
            visit { yield it }
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :argument, :pending, :current

        def advance
          @current = pending.pop
        end

        def visit
          if current.type?(:sym, :str)
            yield current.value.to_s
          elsif current.hash_type?
            pending.concat(current.pairs.reverse.map(&:key))
          elsif current.array_type?
            pending.concat(current.children.reverse)
          end
        end
    end
end
