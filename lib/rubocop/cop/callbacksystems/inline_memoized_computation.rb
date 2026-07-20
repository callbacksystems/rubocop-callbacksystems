# Detects memoization methods that delegate to another method in the same class.
# The computation should be inlined directly in the memoizing method.
#
# @example
#   # bad - delegates to another method
#   def user
#     @user ||= find_user
#   end
#
#   private
#     def find_user
#       User.find(params[:id])
#     end
#
#   # good - computation is inline
#   def user
#     @user ||= User.find(params[:id])
#   end
#
#   # good - calls method on receiver (not delegation)
#   def user
#     @user ||= User.find(params[:id])
#   end
#
#   # good - calls method with arguments
#   def formatted_name
#     @formatted_name ||= format_name(first, last)
#   end
#
#   # good - has additional logic
#   def user
#     @user ||= find_user || default_user
#   end
#
class RuboCop::Cop::Callbacksystems::InlineMemoizedComputation < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Inline the computation from `%<method>s` instead of delegating."

  def on_def(node)
    memoization = Memoization.new(node)
    add_offense(node, message: format(MESSAGE, method: memoization.delegated_method)) if memoization.delegates_to_own_method?
  end

  alias on_defs on_def

  private
    class Memoization
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def delegates_to_own_method?
        node.body&.or_asgn_type? && delegating_call? && enclosing_defines?
      end

      def delegated_method
        node.body.expression.method_name
      end

      private
        attr_reader :node
        delegate :expression, to: "node.body", private: true

        def delegating_call?
          bare_send?(expression) && expression.arguments.empty?
        end

        def enclosing_defines?
          direct_method_nodes_in(enclosing_class_or_module_of(node)&.body).any? { it.method?(delegated_method) }
        end
    end
end
