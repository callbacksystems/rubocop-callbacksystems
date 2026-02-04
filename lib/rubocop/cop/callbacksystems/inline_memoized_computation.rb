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
class RuboCop::Cop::Callbacksystems::InlineMemoizedComputation < RuboCop::Cop::Base
  MESSAGE = "Inline the computation from `%<method>s` instead of delegating."

  def on_def(node)
    return unless node.body&.or_asgn_type?

    expression = node.body.children.last
    add_offense(node, message: format(MESSAGE, method: expression.method_name)) if delegates_to_own_method?(node, expression)
  end

  private
    def delegates_to_own_method?(node, expression)
      expression.send_type? && expression.receiver.nil? && expression.arguments.empty? && method_exists_in_class?(node, expression.method_name)
    end

    def method_exists_in_class?(node, method_name)
      enclosing = node.each_ancestor(:class, :module).first
      enclosing&.each_descendant(:def)&.any? do |def_node|
        def_node.method_name == method_name && direct_child_of_class?(def_node, enclosing)
      end
    end

    def direct_child_of_class?(method_node, class_node)
      method_node.each_ancestor(:class, :module).first == class_node
    end
end
