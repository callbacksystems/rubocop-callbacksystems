# `assert expected, actual` passes whenever `expected` is truthy, so a
# two-argument `assert` usually means `assert_equal`. The second argument is
# legitimate when it reads as a failure message: a string, or a variable or
# method whose name says so. This replaces `Minitest/AssertWithExpectedArgument`,
# which only recognizes string literals and the bare names `message` and `msg`.
#
# @example
#   # bad
#   assert(3, my_list.length)
#   assert(expected, actual)
#
#   # good
#   assert_equal(3, my_list.length)
#   assert foo, "must be present"
#   assert foo, msg
#   assert foo, error_message
#   assert audit.passed?, audit.failure_message
#   assert user.valid?, user.errors
#
class RuboCop::Cop::Callbacksystems::AssertWithExpectedArgument < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Did you mean to use `assert_equal(%<arguments>s)`?"
  RESTRICT_ON_SEND = %i[ assert ]
  MESSAGE_NAME = /message\z|\Amsg\z/
  BOOLEAN_NODE_TYPES = %i[ and false match_pattern_p or true ]
  BOOLEAN_METHODS = %i[ ! =~ !~ ]

  # @!method assert_with_two_arguments?(node)
  def_node_matcher :assert_with_two_arguments?, <<~PATTERN
    (call {nil? (self)} :assert $_ $_)
  PATTERN

  def on_send(node)
    if test_file?(processed_source.file_path)
      assert_with_two_arguments?(node) do |asserted, second_argument|
        unless predicate?(asserted) || message_argument?(second_argument)
          add_offense(node, message: format(MESSAGE, arguments: node.arguments.map(&:source).join(", ")))
        end
      end
    end
  end

  alias on_csend on_send

  private
    # With a predicate asserted there is no expected/actual confusion, so the second argument is a message by intention.
    def predicate?(argument)
      BOOLEAN_NODE_TYPES.include?(argument.type) ||
        (argument.call_type? && (argument.predicate_method? || argument.comparison_method? ||
          BOOLEAN_METHODS.include?(argument.method_name)))
    end

    def message_argument?(argument)
      argument.type?(:str, :dstr) || deferred_callable_block?(argument) || named_like_a_message?(argument)
    end

    def named_like_a_message?(argument)
      name = argument.send_type? ? argument.method_name : argument.source
      name.to_s.match?(MESSAGE_NAME)
    end
end
