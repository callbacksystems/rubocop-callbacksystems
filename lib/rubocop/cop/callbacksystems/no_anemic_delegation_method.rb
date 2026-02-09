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
class RuboCop::Cop::Callbacksystems::NoAnemicDelegationMethod < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::Helpers

  MESSAGE = "Method `%<method>s` only delegates to `%<class>s.new(...).%<target>s`. Consider inlining or removing this method."

  def on_def(node)
    return unless checkable_method?(node)

    delegation = MethodDelegation.new(node)
    add_offense(node, message: delegation.offense_message) if delegation.anemic?
  end

  private
    def checkable_method?(node)
      return false unless node.body&.send_type?

      private_non_predicate?(node)
    end

    def private_non_predicate?(node)
      method_visibility(node) != :public && !node.method_name.to_s.end_with?("?")
    end

    class MethodDelegation
      def initialize(node)
        @node = node
        @body = node.body
      end

      def anemic?
        receiver_is_new_instance? && uses_method_params_only?
      end

      def offense_message
        format MESSAGE, method: node.method_name, class: body.receiver.receiver.short_name, target: body.method_name
      end

      private
        attr_reader :node, :body

        def receiver_is_new_instance?
          body.receiver&.send_type? &&
            body.receiver.method_name == :new &&
            body.receiver.receiver&.const_type?
        end

        def uses_method_params_only?
          new_call_args = body.receiver.arguments.map(&:source)
          method_params = node.arguments.map { |argument| argument.name.to_s }

          new_call_args.all? { |argument| method_params.include?(argument) }
        end
    end
end
