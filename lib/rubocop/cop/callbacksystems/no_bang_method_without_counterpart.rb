# Prohibits bang methods (ending with `!`) unless a non-bang counterpart exists.
# The `!` suffix promises a version without it that is safer, so a lone bang is a
# name that raises a question it never answers.
#
# Instance and singleton methods answer for themselves. A `def self.reload` is no
# counterpart to the `reload!` of an instance, so each side is read against the
# methods that land where it does: the body's own defs, what a `class << self` or a
# `class_methods do` adds to the class, and what an `included do` adds to
# instances.
#
# Counterparts defined in reopenings, ancestors and mixins count wherever the
# project index can resolve the whole ancestry. When any link is unknown, the
# cop abstains rather than calling a method orphaned on incomplete evidence.
#
# @example
#   # bad - no non-bang counterpart
#   def process!
#     # ...
#   end
#
#   # good - has non-bang counterpart
#   def save
#     # safe version
#   end
#
#   def save!
#     save || raise(RecordNotSaved)
#   end
#
#   # good - no bang needed
#   def process
#     # ...
#   end
#
class RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpart < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support

  def on_new_investigation
    @project_index_available = project_index_reliable? && runtime_definitions_absent?
    @local_definitions = LocalDefinitions.new(local_definition_entries)
    @counterparts_by_namespace = {}
  end

  def on_class(node)
    namespace_for(node)&.then do |namespace|
      report_each OrphanBangMethods.new \
        local_definitions.definitions_for(node), counterparts: counterparts_for(namespace)
    end
  end

  alias on_module on_class

  private
    attr_reader :local_definitions, :counterparts_by_namespace, :project_index_available

    def runtime_definitions_absent?
      RuntimeDefinitions.for(project_index).absent?
    end

    def local_definition_entries
      nodes_in(processed_source.ast, :class, :module).filter_map do |container|
        namespace_for(container)&.then { [ container, it.name ] }
      end
    end

    def namespace_for(container)
      return unless project_index_available && container.identifier.const_type?

      resolve_constant_in_index(container.identifier).then { it if it.is_a?(Rubydex::Namespace) }
    rescue
      nil
    end

    def counterparts_for(namespace)
      counterparts_by_namespace[namespace.name] ||= Counterparts.new \
        namespace, local_definitions:, project_index:, processed_source:
    end

    # A project-wide runtime definition leaves the set of possible counterparts open.
    class RuntimeDefinitions
      extend RuboCop::Callbacksystems::ProjectIndex::Cache

      METHOD_NAMES = %w[ define_method define_singleton_method ].to_set

      def initialize(project_index)
        @absent = project_index.method_references.none? do |reference|
          METHOD_NAMES.include?(reference.name.delete_suffix("()"))
        end
      end

      def absent?
        absent
      end

      private
        attr_reader :absent
    end

    # Method definitions classified by the side of the container where Ruby installs them.
    class LocalDefinitions
      def initialize(entries)
        definitions = entries.map { |container, name| [ container, name, ContainerDefinitions.new(container) ] }
        @definitions_by_container = definitions.to_h { |container, _, value| [ container, value ] }.compare_by_identity
        @containers_by_namespace = definitions.group_by { |_, name, _| name }
          .transform_values { it.map(&:last) }
        @possibilities = {}
      end

      def definitions_for(container)
        definitions_by_container.fetch(container)
      end

      def possibly_defines?(namespace_name, name, domain:)
        query = Query.new(namespace_name, name, domain)

        possibilities.fetch(query) do
          possibilities[query] = containers_by_namespace.fetch(namespace_name, []).any? do |container|
            container.possibly_defines?(name, domain:)
          end
        end
      end

      private
        Query = Data.define(:namespace_name, :name, :domain)

        attr_reader :definitions_by_container, :containers_by_namespace, :possibilities

        # Definitions that belong to one lexical class or module body.
        class ContainerDefinitions
          include RuboCop::Callbacksystems::Helpers

          INSTANCE_MACROS = %i[ included prepended ]
          SINGLETON_MACRO = :class_methods
          CONCERN_MACROS = (INSTANCE_MACROS + [ SINGLETON_MACRO ]).to_set
          ALWAYS_UNCERTAIN_CALLS = %i[ delegate_missing_to has_secure_password has_secure_token ].to_set
          NON_DECLARATIVE_CALLS = %i[ extend include prepend private protected public using ].to_set
          UNKNOWN_NAME = Object.new
          Definition = Data.define(:node, :domain)

          def initialize(container)
            @container = container
          end

          def possibly_defines?(name, domain:)
            by_domain.fetch(domain, []).any? { it.method?(name) } ||
              runtime_names.include?(name.to_s) || runtime_names.include?(UNKNOWN_NAME)
          end

          def by_domain
            @by_domain ||= definitions.group_by(&:domain).transform_values { it.map(&:node) }
          end

          private
            attr_reader :container

            def definitions
              @definitions ||= method_definitions + macro_definitions
            end

            def method_definitions
              direct_method_nodes_in(container.body).filter_map do |definition|
                if definition.def_type? || definition.receiver.self_type?
                  Definition.new(definition, RuboCop::Callbacksystems::Methods::Domain.new(definition).identity)
                end
              end
            end

            def macro_definitions
              INSTANCE_MACROS.flat_map { definitions_in_macro(it, domain: []) } +
                definitions_in_macro(SINGLETON_MACRO, domain: [ :self ])
            end

            def definitions_in_macro(macro, domain:)
              statements_in(container.body).flat_map do |statement|
                if macro_block?(statement, macro:)
                  direct_definitions_in(statement.body, :def).map { Definition.new(it, domain) }
                else
                  []
                end
              end
            end

            def macro_block?(statement, macro:)
              if any_block_type?(statement)
                call_on_self?(call_of(statement)) && statement.method?(macro)
              else
                false
              end
            end

            def runtime_names
              @runtime_names ||= runtime_names_from_calls.to_set |
                (ambiguous_definition? ? Set[UNKNOWN_NAME] : Set.new)
            end

            def runtime_names_from_calls
              scoped_calls.flat_map { runtime_names_from(it) }
            end

            def scoped_calls
              @scoped_calls ||= nodes_in(container.body, :send, :csend).select { belongs_to_container?(it) }
            end

            def belongs_to_container?(node)
              enclosing_class_or_module_of(node).equal?(container) && enclosing_method_of(node).nil?
            end

            def runtime_names_from(call)
              indexed_names = RuboCop::Callbacksystems::Methods::StatementDefinitions.new(call).names

              if always_uncertain?(call) || indexed_names.nil?
                [ UNKNOWN_NAME ]
              elsif indexed_names.any?
                indexed_names.map(&:to_s)
              elsif declarative_call?(call)
                names_in_arguments(call.arguments)
              else
                []
              end
            end

            def always_uncertain?(call)
              ALWAYS_UNCERTAIN_CALLS.include?(call.method_name) ||
                (call.method?(:module_function) && call.arguments.empty?)
            end

            def declarative_call?(call)
              [ call.receiver.nil? || call.receiver.self_type?, NON_DECLARATIVE_CALLS.exclude?(call.method_name) ].all?
            end

            def names_in_arguments(arguments)
              arguments.map { it.type?(:sym, :str) ? it.value.to_s : UNKNOWN_NAME }
            end

            def ambiguous_definition?
              scoped_definitions.any? do |definition|
                owner = RuboCop::Callbacksystems::Methods::Domain.new(definition).container

                !owner.equal?(container) && !direct_concern_definition?(definition, owner:)
              end
            end

            def scoped_definitions
              @scoped_definitions ||= nodes_in(container.body, :def, :defs).select { belongs_to_container?(it) }
            end

            def direct_concern_definition?(definition, owner:)
              any_block_type?(owner) && call_on_self?(call_of(owner)) && CONCERN_MACROS.include?(owner.method_name) &&
                direct_definitions_in(owner.body, :def).include?(definition)
            end
        end
    end

    # Names that might answer a bang method, with absence trusted only across complete ancestry.
    class Counterparts
      include RuboCop::Cop::ProjectIndexHelp

      SINGLETON_DOMAIN = [ :self ]
      DYNAMIC_DISPATCH_METHODS = %i[ method_missing respond_to_missing? ]
      Query = Data.define(:name, :domain)

      attr_reader :namespace, :local_definitions, :project_index, :processed_source

      def initialize(namespace, local_definitions:, project_index:, processed_source:)
        @namespace = namespace
        @local_definitions = local_definitions
        @project_index = project_index
        @processed_source = processed_source
        @absences = {}
        @complete_domains = {}
      end

      def absent?(name, domain:)
        query = Query.new(name, domain)

        absences.fetch(query) { absences[it] = CounterpartSearch.new(it, context: self).absent? }
      end

      def complete?(indexed_domain, domain:)
        complete_domains.fetch(domain) do
          ancestors = (namespace.ancestors.to_a + indexed_domain.ancestors.to_a).uniq(&:name)

          complete_domains[domain] = resolved_ancestry?(indexed_domain, ignore_extend: domain.empty?) &&
            definitions_in_other_files(ancestors.flat_map { it.definitions.to_a }).empty?
        end
      rescue
        false
      end

      private
        attr_reader :absences, :complete_domains

        def resolved_ancestry?(indexed_domain, ignore_extend:)
          fully_resolved_index_ancestry?(namespace, ignore_extend:) &&
            fully_resolved_index_ancestry?(indexed_domain)
        end

        class CounterpartSearch
          def initialize(query, context:)
            @query = query
            @context = context
          end

          def absent?
            if query.domain.all? { it == :self } && indexed_domain
              !counterpart_possible? && !dynamic_dispatch_possible? &&
                context.complete?(indexed_domain, domain: query.domain)
            else
              false
            end
          rescue
            false
          end

          private
            attr_reader :query, :context
            delegate :namespace, to: :context, private: true

            def indexed_domain
              @indexed_domain ||= query.domain.inject(namespace) { |owner, _| owner&.singleton_class }
            end

            def counterpart_possible?
              indexed_name_possible?(query.name, namespaces: indexed_domain.ancestors) ||
                concern_name_possible?(query.name)
            end

            def indexed_name_possible?(name, namespaces:, local_domain: nil, project_only: false)
              namespaces.any? do |indexed_namespace|
                NamespaceMember.new(indexed_namespace, name:, context:, local_domain:, project_only:).possible?
              end
            end

            def concern_name_possible?(name, project_only: false)
              query.domain == SINGLETON_DOMAIN && indexed_name_possible?(
                name, namespaces: namespace.ancestors, local_domain: SINGLETON_DOMAIN, project_only:
              )
            end

            def dynamic_dispatch_possible?
              DYNAMIC_DISPATCH_METHODS.any? do |method_name|
                indexed_name_possible?(method_name, namespaces: indexed_domain.ancestors, project_only: true) ||
                  concern_name_possible?(method_name, project_only: true)
              end
            end
        end

        class NamespaceMember
          def initialize(indexed_namespace, name:, context:, local_domain:, project_only:)
            @indexed_namespace = indexed_namespace
            @name = name
            @context = context
            @local_domain = local_domain
            @project_only = project_only
          end

          def possible?
            locally_possible? || indexed_declaration_possible?
          rescue
            true
          end

          private
            attr_reader :indexed_namespace, :name, :context, :local_domain, :project_only

            def locally_possible?
              namespace = indexed_namespace
              domain = []

              while namespace.is_a?(Rubydex::SingletonClass)
                domain << :self
                namespace = namespace.owner
              end

              context.local_definitions.possibly_defines?(namespace.name, name, domain: local_domain || domain)
            end

            def indexed_declaration_possible?
              if declaration.is_a?(Rubydex::Method)
                project_scope_allows? && readable? && usable?
              else
                false
              end
            end

            def declaration
              @declaration ||= indexed_namespace.member("#{name}()")
            end

            def project_scope_allows?
              !project_only || definitions.any? do |definition|
                definition.location.uri.start_with?(RuboCop::Cop::ProjectIndexHelp::FILE_URI_PREFIX)
              end
            end

            def definitions
              @definitions ||= declaration.definitions.to_a
            end

            # Rubydex 0.4 indexes an `attr_writer :name` member as `name()`, although Ruby only defines `name=`.
            def readable?
              definitions.empty? || definitions.any? { it.class.name != "Rubydex::AttrWriterDefinition" }
            end

            def usable?
              definitions.empty? || indexed_namespace.is_a?(Rubydex::SingletonClass) || definitions.any? do |definition|
                !definition.location.uri.start_with?(RuboCop::Cop::ProjectIndexHelp::FILE_URI_PREFIX) ||
                  !definition.is_a?(Rubydex::MethodDefinition)
              end
            end
        end
    end

    # The bang methods of one body with no plain counterpart within reach of where they land.
    class OrphanBangMethods
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method `%<method>s` has no non-bang counterpart. Only use `!` when a version without `!` exists."

      def initialize(container_definitions, counterparts:)
        @container_definitions = container_definitions
        @counterparts = counterparts
      end

      def each_offense
        container_definitions.by_domain.flat_map { |domain, definitions| orphans_among(definitions, domain:) }
          .each { yield offense_for(it) }
      end

      private
        attr_reader :container_definitions, :counterparts

        def orphans_among(definitions, domain:)
          definitions.select do |definition|
            conventional_bang_method?(definition) && counterparts.absent?(plain_name_of(definition), domain:)
          end
        end

        def conventional_bang_method?(definition)
          definition.bang_method? && !definition.method?(:!)
        end

        def plain_name_of(definition)
          definition.method_name.to_s.chomp("!").to_sym
        end

        def offense_for(definition)
          RuboCop::Callbacksystems::Offense.new(definition, format(MESSAGE, method: definition.method_name))
        end
    end
end
