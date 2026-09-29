# A constant reference does not need to repeat the namespace it is already
# written inside. The prefix is noise on every read, and it has to be rewritten
# whenever the namespace moves, while the bare name resolves through the scope
# the file already opens.
#
# Only the innermost lexical scope counts. Under the compact class style a
# definition like `class PgBox::Configuration` opens a single scope, so `PgBox`
# itself is never searched and its prefix has to stay.
#
# @example
#   # bad
#   class PgBox::Configuration
#     def validator
#       PgBox::Configuration::Validator
#     end
#   end
#
#   # good
#   class PgBox::Configuration
#     def validator
#       Validator
#     end
#   end
#
#   # good - `PgBox` is not a lexical scope here, so the prefix is required
#   class PgBox::Configuration
#     def secrets
#       PgBox::Secrets
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::RedundantConstantNamespace < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @constant_references = if project_index_reliable?
      RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(project_index).within(processed_source)
    end
  end

  def on_const(node)
    report ConstantReference.new(node, constant_references) if constant_references
  end

  private
    attr_reader :constant_references

    class ConstantReference
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Remove the redundant `%<namespace>s::` prefix; the constant already resolves from here."

      def initialize(node, constant_references)
        @node = node
        @constant_references = constant_references
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) { correct(it) } if reference? && redundantly_qualified?
      end

      private
        attr_reader :node, :constant_references

        def reference?
          !node.parent&.const_type? && !definition_identifier?(node)
        end

        def redundantly_qualified?
          enclosing_scope_name.present? && qualified_node.present? && explicitly_declared_scope? && same_declaration?
        end

        def enclosing_scope_name
          @enclosing_scope_name ||= enclosing_definitions.map { constant_name_of(it.identifier) }.join("::")
        end

        def enclosing_definitions
          node.each_ancestor(:class, :module).to_a.reverse
        end

        def qualified_node
          @qualified_node ||= constant_chain.find { constant_name_of(it.namespace) == enclosing_scope_name }
        end

        def constant_chain
          [ node, *node.each_descendant(:const) ].select(&:namespace)
        end

        def explicitly_declared_scope?
          enclosing_scope_chain.present? && enclosing_scope_chain.all? { declared_namespace?(it) } &&
            enclosing_scope_chain.last.owner&.name == "Object"
        end

        def enclosing_scope_chain
          @enclosing_scope_chain ||= Enumerator.produce(enclosing_scope_declaration) { it&.owner }
            .take_while { it.present? && it.name != "Object" }
        end

        def enclosing_scope_declaration
          constant_references.referenced_declaration_for(qualified_node.namespace)
        end

        def declared_namespace?(declaration)
          declaration.is_a?(Rubydex::Namespace) && declared?(declaration)
        end

        def declared?(declaration)
          declaration&.definitions&.any?
        end

        def same_declaration?
          written_declaration = constant_references.referenced_declaration_for(node)
          shortened_declaration = constant_references.declaration_named(shortened_name, beside: node)

          declared?(written_declaration) && declared?(shortened_declaration) &&
            written_declaration.name == shortened_declaration.name
        end

        def shortened_name
          chain = [ node ]
          chain << chain.last.namespace until chain.last.equal?(qualified_node)
          chain.reverse_each.map(&:short_name).join("::")
        end

        def message
          format(MESSAGE, namespace: enclosing_scope_name)
        end

        def correct(corrector)
          corrector.remove(node.source_range.with(end_pos: qualified_node.loc.name.begin_pos))
        end
    end
end
