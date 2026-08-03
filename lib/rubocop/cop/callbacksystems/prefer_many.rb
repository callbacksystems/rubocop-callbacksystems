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
# `many?` comes from Enumerable, so a receiver that is plainly a String is left
# alone: `"abc".length > 1` reads the same but `"abc".many?` does not exist.
#
class RuboCop::Cop::Callbacksystems::PreferMany < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `many?` instead of `%<method>s > 1`."

  # @!method size_greater_than_one?(node)
  def_node_matcher :size_greater_than_one?, <<~PATTERN
    (send (call $_ ${:size :length :count}) :> (int 1))
  PATTERN

  def on_send(node)
    size_greater_than_one?(node) do |receiver, method|
      next if string_receiver?(receiver)

      add_offense(node, message: format(MESSAGE, method: method)) do |corrector|
        corrector.replace(node, "#{receiver.source}.many?")
      end
    end
  end

  alias on_csend on_send

  private
    def string_receiver?(receiver)
      receiver.any_str_type? || coerced_to_string?(receiver)
    end

    def coerced_to_string?(receiver)
      receiver.call_type? && receiver.method?(:to_s)
    end
end
