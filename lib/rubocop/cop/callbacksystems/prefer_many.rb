# Detects `collection.size > 1` patterns that should use `many?`. The predicate
# asks the question in one word, where the comparison makes the reader count.
#
# `size`, `length` and `count` answer for a String too, while `many?` comes from
# `Enumerable` and a String is not one, so a receiver we can read as a String is
# left alone. A receiver whose type the file does not show stays flagged: getting
# it wrong raises on the first call rather than passing quietly.
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
#   # good - a String has no `many?`
#   name.strip.length > 1
#
class RuboCop::Cop::Callbacksystems::PreferMany < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `many?` instead of `%<method>s > 1`."

  # @!method size_greater_than_one?(node)
  def_node_matcher :size_greater_than_one?, <<~PATTERN
    (call $(call _ ${:size :length :count}) :> (int 1))
  PATTERN

  def on_send(node)
    size_greater_than_one?(node) do |size_call, method|
      next if string_receiver?(size_call.receiver)

      add_many_offense(node, call: size_call, method:)
    end
  end

  alias on_csend on_send

  private
    def string_receiver?(receiver)
      reads_as_string?(receiver)
    end

    def add_many_offense(node, call:, method:)
      if source_comments.any_within?(node)
        add_offense(node, message: format(MESSAGE, method:))
      else
        add_offense(node, message: format(MESSAGE, method:)) { it.replace(node, replacement_for(call)) }
      end
    end

    def replacement_for(call)
      "#{call_prefix_of(call)}many?"
    end
end
