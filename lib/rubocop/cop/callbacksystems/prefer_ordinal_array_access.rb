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
class RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccess < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  ORDINAL_METHODS = {
    1 => :second,
    2 => :third,
    3 => :fourth,
    4 => :fifth,
    -2 => :second_to_last,
    -3 => :third_to_last
  }.freeze

  # Matches: receiver[integer]
  def_node_matcher :bracket_access_with_int?, <<~PATTERN
    (send $_ :[] (int $_index))
  PATTERN

  def on_send(node)
    bracket_access_with_int?(node) do |receiver, index|
      ordinal_method = ORDINAL_METHODS[index]
      next unless ordinal_method

      add_offense(node, message: "Use `#{ordinal_method}` instead of `[#{index}]`.") do |corrector|
        corrector.replace(node.source_range, "#{receiver.source}.#{ordinal_method}")
      end
    end
  end
end
