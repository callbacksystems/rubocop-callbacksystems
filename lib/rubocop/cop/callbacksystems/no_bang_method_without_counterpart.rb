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
    each_offense(node) { |method_node, message| add_offense(method_node, message: message) }
  end

  alias on_module on_class

  private
    def each_offense(node, &block)
      if block
        orphan_bang_methods_in(node).each { yield it, format(MESSAGE, method: it.method_name) }
      else
        to_enum(__method__, node)
      end
    end

    def orphan_bang_methods_in(node)
      methods = direct_method_nodes_in(node.body)
      names = methods.to_set(&:method_name)

      methods.select { it.bang_method? && !names.include?(it.method_name.to_s.chomp("!").to_sym) }
    end
end
