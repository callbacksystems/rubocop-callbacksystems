# Detects `collection.size > 1` patterns that should use `many?`.
#
# @example
#   # bad
#   users.size > 1
#   users.length > 1
#   users.count > 1
#
#   # good
#   users.many?
#
class RuboCop::Cop::Callbacksystems::PreferMany < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  # Matches: something.size > 1, something.length > 1, something.count > 1
  def_node_matcher :size_greater_than_one?, <<~PATTERN
    (send (send $_ ${:size :length :count}) :> (int 1))
  PATTERN

  def on_send(node)
    size_greater_than_one?(node) do |receiver, method|
      add_offense(node, message: "Use `many?` instead of `#{method} > 1`.") do |corrector|
        corrector.replace(node.source_range, "#{receiver.source}.many?")
      end
    end
  end
end
