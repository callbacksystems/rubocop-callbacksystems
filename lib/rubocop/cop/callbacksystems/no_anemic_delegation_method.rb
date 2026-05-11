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
class RuboCop::Cop::Callbacksystems::NoAnemicDelegationMethod < RuboCop::Cop::Callbacksystems::Base
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
            body.receiver.method?(:new) &&
            body.receiver.receiver&.const_type?
        end

        def uses_method_params_only?
          body.receiver.arguments.map(&:source).all? do |argument|
            node.arguments.map { it.name.to_s }.include?(argument)
          end
        end
    end
end
