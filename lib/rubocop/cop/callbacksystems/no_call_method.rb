# Prohibits defining methods named `call`. This pattern is associated with service objects which we avoid.
#
# @example
#   # bad
#   class OrderProcessor
#     def call
#       # ...
#     end
#   end
#
#   # bad
#   class OrderProcessor
#     def self.call
#       # ...
#     end
#   end
#
#   # good - use descriptive method names
#   class Order
#     def process
#       # ...
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoCallMethod < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Avoid defining `call` methods. Use descriptive method names instead."

  def on_def(node)
    add_offense(node, message: MESSAGE) if node.method?(:call)
  end

  alias on_defs on_def
end
