# A class whose whole body is class-level code should be a module with
# `extend self`. Classes are for making instances.
#
# `Style/StaticClass` covers the plain case, but it abstains as soon as the
# singleton section has a private part, because the `module_function` it
# corrects to stops copying methods to the singleton once `private` switches
# the mode, which breaks every call to them. `extend self` carries the
# visibility over untouched, so that case is reported here instead.
#
# @example
#   # bad - class methods only, with a private helper
#   class Architecture
#     class << self
#       def resolve(reports)
#         normalize(reports)
#       end
#
#       private
#         def normalize(raw)
#           raw.downcase
#         end
#     end
#   end
#
#   # good
#   module Architecture
#     extend self
#
#     def resolve(reports)
#       normalize(reports)
#     end
#
#     private
#       def normalize(raw)
#         raw.downcase
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferModuleForStaticClass < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support

  def on_class(node)
    if project_index_reliable?
      inspect_candidate StaticClass.new(node), node:
    end
  end

  private
    def inspect_candidate(analysis, node:)
      declaration = convertible_declaration_of(node) if analysis.candidate?
      report analysis if declaration && module_preferred?(analysis, declaration:)
    end

    def convertible_declaration_of(node)
      declaration = resolve_constant_in_index(node.identifier)
      declaration if declaration.is_a?(Rubydex::Class) && project_declaration_reliable?(declaration)
    end

    def module_preferred?(analysis, declaration:)
      analysis.compatible_with_module?(declaration) && !class_required?(declaration)
    end

    def class_required?(declaration)
      inherited_callback_observable? || definitions_in_other_files(declaration.definitions).any? ||
        !declaration.definitions.one? ||
        declaration.descendants.any? { it.name != declaration.name } ||
        !project_references.compatible_with_module?(declaration)
    end

    def inherited_callback_observable?
      [ project_index["Object"].singleton_class, project_index["Class"] ].compact.any? do |namespace|
        namespace.find_member("inherited()")&.definitions&.any?
      end
    end

    def project_references
      ProjectReferences.for(project_index)
    end

    # Every reference must prove that replacing the declaration with a module preserves what that line does.
    class ProjectReferences
      extend RuboCop::Callbacksystems::ProjectIndex::Cache

      def initialize(project_index)
        @method_references_by_receiver = grouped_references(project_index.method_references) { receiver_name_of(it) }
        @constant_references_by_owner = grouped_references(project_index.constant_references) { owner_name_of(it) }
      end

      def compatible_with_module?(declaration)
        declaration.references.all? do |reference|
          ReferenceUse.new(
            reference,
            declaration:,
            method_references: method_references_for(declaration),
            constant_references: constant_references_for(declaration)
          ).compatible?
        end
      end

      private
        attr_reader :method_references_by_receiver, :constant_references_by_owner

        def grouped_references(references)
          references.each_with_object({}) do |reference, groups|
            yield(reference)&.then do |group|
              locations = groups[group] ||= {}
              (locations[location_key(reference.location)] ||= []) << reference
            end
          end
        end

        def location_key(location)
          [ location.uri, location.start_line, location.start_column ]
        end

        def receiver_name_of(reference)
          receiver = reference.receiver
          receiver.attached_class.name if receiver.is_a?(Rubydex::SingletonClass)
        end

        def owner_name_of(reference)
          reference.declaration.owner.name if reference.is_a?(Rubydex::ResolvedConstantReference)
        end

        def method_references_for(declaration)
          method_references_by_receiver.fetch(declaration.name) { {} }
        end

        def constant_references_for(declaration)
          constant_references_by_owner.fetch(declaration.name) { {} }
        end

        class ReferenceUse
          def initialize(reference, declaration:, method_references:, constant_references:)
            @reference = reference
            @declaration = declaration
            @method_references = method_references
            @constant_references = constant_references
          end

          def compatible?
            direct_declared_method? || namespace_reference?
          end

          private
            attr_reader :reference, :declaration, :method_references, :constant_references

            def direct_declared_method?
              adjacent_references_in(method_references).any? { declared_on_singleton?(it.name) }
            end

            def adjacent_references_in(references, separator_width: nil)
              expected_columns(separator_width).flat_map do |column|
                references.fetch(location_key(column)) { [] }
              end
            end

            def expected_columns(separator_width)
              widths = separator_width ? [ separator_width ] : [ 1, 2 ]
              widths.to_set { reference.location.end_column + it }
            end

            def location_key(column)
              [ reference.location.uri, reference.location.end_line, column ]
            end

            def declared_on_singleton?(method_name)
              declaration.singleton_class.member("#{method_name}()").present?
            end

            def namespace_reference?
              adjacent_references_in(constant_references, separator_width: 2).any?
            end
        end
    end

    class StaticClass
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Prefer a module with `extend self` to a class holding only class methods."
      CLASS_ONLY_CALLBACKS = %i[ inherited ]
      VISIBILITY_METHODS = %i[ private protected public ]

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE)
      end

      def candidate?
        convertible? && private_singleton_section?
      end

      def compatible_with_module?(declaration)
        !class_semantics_used? && singleton_calls_owned_by?(declaration)
      end

      private
        attr_reader :node

        def convertible?
          node.parent_class.nil? && only_class_level_statements?
        end

        def only_class_level_statements?
          statements.any? && statements.all? { class_level_statement?(it) }
        end

        def statements
          @statements ||= statements_in(node.body)
        end

        def class_level_statement?(statement)
          statement.type?(:casgn, :defs) || extend_call?(statement) || singleton_section?(statement)
        end

        def extend_call?(statement)
          bare_send?(statement) && statement.method?(:extend)
        end

        def private_singleton_section?
          statements.select { singleton_section?(it) }.any? { holds_private_section?(it) }
        end

        def holds_private_section?(section)
          private_modifier_in(section.body).present?
        end

        def class_semantics_used?
          class_only_callback_defined? || method_name_rebound? || singleton_super? || self_value_used?
        end

        def class_only_callback_defined?
          nodes_in(node.body, :def, :defs).any? { CLASS_ONLY_CALLBACKS.include?(it.method_name) }
        end

        def method_name_rebound?
          nodes_in(node.body, :alias, :undef).any? || nodes_in(node.body, :send, :csend).any? do |send_node|
            send_node.method?(:alias_method) || send_node.method?(:undef_method)
          end
        end

        def singleton_super?
          nodes_in(node.body, :super, :zsuper).any?
        end

        def self_value_used?
          nodes_in(node.body, :self).any? do |self_node|
            enclosing_class_or_module_of(self_node).equal?(node) && !structural_self?(self_node)
          end
        end

        def singleton_calls_owned_by?(declaration)
          candidate_singleton_calls.all? do |send_node|
            visibility_modifier?(send_node) || owned_method?(send_node.method_name, declaration:)
          end
        end

        def candidate_singleton_calls
          nodes_in(node.body, :send, :csend).select do |send_node|
            call_on_self?(send_node) && candidate_singleton_domain?(send_node)
          end
        end

        def candidate_singleton_domain?(send_node)
          RuboCop::Callbacksystems::Methods::Domain.new(send_node).then do |domain|
            (domain.container.equal?(node) && domain.identity.present? && domain.identity.all? { it == :self }) ||
              opaque_block_in_candidate?(domain.container)
          end
        end

        def opaque_block_in_candidate?(container)
          any_block_type?(container) && enclosing_class_or_module_of(container).equal?(node)
        end

        def visibility_modifier?(send_node)
          enclosing_method_of(send_node).nil? && VISIBILITY_METHODS.include?(send_node.method_name)
        end

        def owned_method?(method_name, declaration:)
          declaration.singleton_class.member("#{method_name}()").present?
        end
    end
end
