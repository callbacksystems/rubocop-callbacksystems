# Detects private methods that only call another method without adding value.
# Such wrapper methods add indirection without purpose.
# Public methods and predicates are excluded as they often provide semantic value.
#
# @example
#   # bad - private wrapper just calls another method
#   private
#     def find_all
#       find(@node)
#     end
#
#   # good - public method (may be API or provide semantic meaning)
#   def authenticated?
#     resume_session
#   end
#
#   # good - predicate provides semantic alias
#   def fulfillable?
#     paid?
#   end
#
#   # good - method does something meaningful
#   def find_all
#     find(@node).compact
#   end
#
class RuboCop::Cop::Callbacksystems::NoRedundantWrapperMethod < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Method `%<wrapper>s` only wraps `%<target>s` without adding value. Consider removing the indirection."

  def on_def(node)
    return unless checkable_method?(node)

    wrapper = WrapperMethod.new(node)
    add_offense(node, message: wrapper.offense_message) if wrapper.redundant?
  end

  private
    def checkable_method?(node)
      return false unless node.body&.send_type?

      private_non_predicate?(node)
    end

    class WrapperMethod
      def initialize(node)
        @node = node
        @body = node.body
      end

      def redundant?
        simple_method_call? && arguments_are_pass_through?
      end

      def offense_message
        format(MESSAGE, wrapper: node.method_name, target: body.method_name)
      end

      private
        attr_reader :node, :body

        def simple_method_call?
          body.receiver.nil? || body.receiver.self_type?
        end

        def arguments_are_pass_through?
          return true if body.arguments.empty?

          (body.arguments.map { argument_source(it) } -
            node.arguments.map { it.name.to_s } -
            body.arguments.select(&:ivar_type?).map(&:source)).empty?
        end

        def argument_source(arg)
          arg.lvar_type? ? arg.children.first.to_s : arg.source
        end
    end
end
