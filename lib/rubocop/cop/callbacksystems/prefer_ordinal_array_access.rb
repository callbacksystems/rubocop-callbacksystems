# Detects array access with numeric indices that could use ordinal methods.
#
# @example
#   # bad
#   items[1]
#   items[2]
#   items[3]
#   items[4]
#   items[-2]
#   items[-3]
#
#   # good
#   items.second
#   items.third
#   items.fourth
#   items.fifth
#   items.second_to_last
#   items.third_to_last
#
class RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccess < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `%<method>s` instead of `[%<index>s]`."

  ORDINAL_METHODS = {
    1 => :second,
    2 => :third,
    3 => :fourth,
    4 => :fifth,
    -2 => :second_to_last,
    -3 => :third_to_last
  }.freeze

  # @!method bracket_access_with_int?(node)
  def_node_matcher :bracket_access_with_int?, <<~PATTERN
    (send $_ :[] (int $_index))
  PATTERN

  def on_send(node)
    bracket_access_with_int?(node) do |receiver, index|
      next unless (ordinal_method = ORDINAL_METHODS[index])

      add_offense(node, message: format(MESSAGE, method: ordinal_method, index: index)) do |corrector|
        corrector.replace(node, "#{receiver.source}.#{ordinal_method}")
      end
    end
  end

  alias on_csend on_send
end
