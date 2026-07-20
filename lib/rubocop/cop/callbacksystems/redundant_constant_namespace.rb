# A constant reference does not need to repeat the namespace it is already
# written inside.
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
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Remove the redundant `%<namespace>s::` prefix; the constant already resolves from here."

  def on_const(node)
    reference = ConstantReference.new(node)
    add_offense(node, message: reference.offense_message) { reference.shorten(it) } if reference.offense?
  end

  private
    class ConstantReference
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        reference? && redundantly_qualified?
      end

      def offense_message
        format(MESSAGE, namespace: enclosing_scope_name)
      end

      def shorten(corrector)
        corrector.remove(node.source_range.with(end_pos: qualified_node.loc.name.begin_pos))
      end

      private
        attr_reader :node

        def reference?
          !node.parent&.const_type? && !definition_identifier?(node)
        end

        def redundantly_qualified?
          enclosing_scope_name.present? && qualified_node.present?
        end

        def enclosing_scope_name
          @enclosing_scope_name ||= enclosing_definitions.map { constant_name_of(it.identifier) }.join("::")
        end

        def enclosing_definitions
          node.each_ancestor(:class, :module).to_a.reverse
        end

        # The link of the chain whose own namespace is the enclosing scope, so
        # dropping everything before its name leaves a constant that still
        # resolves through that scope.
        def qualified_node
          @qualified_node ||= constant_chain.find { constant_name_of(it.namespace) == enclosing_scope_name }
        end

        def constant_chain
          [ node, *node.each_descendant(:const) ].select(&:namespace)
        end
    end
end
