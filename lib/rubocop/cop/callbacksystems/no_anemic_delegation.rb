# Detects private methods that only delegate to a newly created object.
# Such methods add indirection without value and should be inlined or reconsidered.
# Public methods and predicates are excluded as they often provide semantic value.
#
# @example
#   # bad - private method only creates object and calls single method
#   private
#     def eager_loading_association(body)
#       ScopeBody.new(body).eager_loading_association
#     end
#
#   # good - inline the call
#   ScopeBody.new(body).eager_loading_association
#
#   # good - public method (may be API)
#   def eager_loading_association(body)
#     ScopeBody.new(body).eager_loading_association
#   end
#
#   # good - predicate adds semantic meaning
#   def valid?
#     Validator.new(self).valid?
#   end
#
class RuboCop::Cop::Callbacksystems::NoAnemicDelegation < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report MethodDelegation.new(node)
  end

  alias on_defs on_def

  private
    class MethodDelegation
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method `%<method>s` only delegates to `%<class>s.new(...).%<target>s`. Consider inlining or " \
        "removing this method."

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if anemic_delegation?
      end

      private
        attr_reader :node
        delegate :body, to: :node, private: true

        def anemic_delegation?
          eligible_method? && delegates_only_parameters?
        end

        def eligible_method?
          single_send_private_non_predicate?(node) && direct_method_declaration?
        end

        def direct_method_declaration?
          owner && transparent_parents?
        end

        def owner
          @owner ||= enclosing_class_or_module_of(node)
        end

        def transparent_parents?
          node.each_ancestor.take_while { !it.equal?(owner) }.all? { transparent_method_parent?(it) }
        end

        def transparent_method_parent?(parent)
          parent.type?(:begin, :kwbegin, :sclass) || visibility_applied_to(parent, node)
        end

        def delegates_only_parameters?
          receiver_is_new_instance? && passes_only_parameters?
        end

        def receiver_is_new_instance?
          body.receiver&.send_type? &&
            body.receiver.method?(:new) &&
            body.receiver.receiver&.const_type?
        end

        def passes_only_parameters?
          invocation_arguments.all? { it.lvar_type? && parameter_names.include?(it.name) }
        end

        def invocation_arguments
          body.receiver.arguments + body.arguments
        end

        def parameter_names
          @parameter_names ||= node.arguments.children.filter_map { it.name if it.respond_to?(:name) }
        end

        def message
          format(MESSAGE, method: node.method_name, class: body.receiver.receiver.short_name, target: body.method_name)
        end
    end
end
