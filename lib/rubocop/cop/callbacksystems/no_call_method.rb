# Prohibits defining methods named `call`.
# This pattern is associated with service objects which we avoid.
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
class RuboCop::Cop::Callbacksystems::NoCallMethod < RuboCop::Cop::Base
  MESSAGE = "Avoid defining `call` methods. Use descriptive method names instead."

  def on_def(node)
    return unless node.method_name == :call

    add_offense(node, message: MESSAGE)
  end

  alias on_defs on_def
end
