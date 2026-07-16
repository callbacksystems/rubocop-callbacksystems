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

  NON_ARRAY_LITERAL_TYPES = %i[ dstr dsym hash int regexp str sym xstr ].freeze
  NON_ARRAY_RESULT_METHODS = %i[ last_match match ].freeze

  # @!method bracket_access_with_int?(node)
  def_node_matcher :bracket_access_with_int?, <<~PATTERN
    (send $_ :[] (int $_index))
  PATTERN

  def on_send(node)
    bracket_access_with_int?(node) do |receiver, index|
      ordinal_method = ORDINAL_METHODS[index]
      if ordinal_method && !known_non_array_receiver?(receiver)
        add_offense(node, message: format(MESSAGE, method: ordinal_method, index: index)) do |corrector|
          corrector.replace(node, "#{receiver.source}.#{ordinal_method}")
        end
      end
    end
  end

  alias on_csend on_send

  private
    def known_non_array_receiver?(receiver)
      NON_ARRAY_LITERAL_TYPES.include?(receiver.type) ||
        (receiver.send_type? && NON_ARRAY_RESULT_METHODS.include?(receiver.method_name))
    end
end
