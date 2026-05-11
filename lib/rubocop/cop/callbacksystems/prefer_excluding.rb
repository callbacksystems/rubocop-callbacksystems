# Detects `array - [element]` patterns that should use `excluding`.
#
# @example
#   # bad
#   users - [admin]
#   items - [first_item]
#
#   # good
#   users.excluding(admin)
#   items.excluding(first_item)
#
class RuboCop::Cop::Callbacksystems::PreferExcluding < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `excluding` instead of `- [element]`."

  # @!method minus_single_element_array?(node)
  def_node_matcher :minus_single_element_array?, <<~PATTERN
    (send $_ :- (array $_element))
  PATTERN

  def on_send(node)
    minus_single_element_array?(node) do |receiver, element|
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.excluding(#{element.source})")
      end
    end
  end

  alias on_csend on_send
end
