# Prohibits bang methods (ending with `!`) unless a non-bang counterpart exists.
# The `!` suffix should only be used when there's a "safer" version without the bang.
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
  MESSAGE = "Method `%<method>s` has no non-bang counterpart. Only use `!` when a version without `!` exists."

  def on_class(node)
    return unless node.body

    methods = direct_method_nodes(node.body)
    names = methods.to_set(&:method_name)

    names.select { it.to_s.end_with?("!") }.each do |bang_method|
      next if names.include?(bang_method.to_s.chomp("!").to_sym)

      method_node = methods.find { it.method?(bang_method) }
      add_offense(method_node, message: format(MESSAGE, method: bang_method)) if method_node
    end
  end

  alias on_module on_class
end
