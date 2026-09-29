# Constants are read, never mutated, so freezing one guards against a mistake
# nobody makes and puts noise on every declaration. Core `Style/MutableConstant`
# asks for the opposite and stays off, while `Style/RedundantFreeze` reports the
# same line whenever the value was immutable already.
#
# @example
#   # bad
#   FORMATS = [ :json ].freeze
#   TIMEOUT = "30s".freeze
#
#   # good
#   FORMATS = [ :json ]
#   TIMEOUT = "30s"
#
class RuboCop::Cop::Callbacksystems::RedundantConstantFreeze < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Remove `freeze`. A constant is read, not mutated."

  def on_casgn(node)
    call = frozen_call_in(node)

    report call if call
  end

  private
    def frozen_call_in(node)
      expression = node.children.last
      expression = expression.children.first while parenthesized_expression?(expression)
      expression if freezing_call?(expression)
    end

    def parenthesized_expression?(node)
      node.begin_type? && node.children.one?
    end

    def freezing_call?(node)
      node.call_type? && node.receiver && freezes_without_arguments?(node)
    end

    def freezes_without_arguments?(node)
      node.method?(:freeze) && node.arguments.empty?
    end

    def report(call)
      range = freeze_range_of(call)
      if source_comments.any_within?(range)
        add_offense(range, message: MESSAGE)
      else
        add_offense(range, message: MESSAGE) { it.remove(range) }
      end
    end

    def freeze_range_of(call)
      call.source_range.with(begin_pos: call.loc.dot.begin_pos)
    end
end
