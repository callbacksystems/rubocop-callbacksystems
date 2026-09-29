# Detects multiline expressions that can fit on a single line and collapses them.
# Applies to hash literals, array literals, and method calls with backslash
# continuation or parenthesized arguments. An expression spread over several
# lines when one would hold it costs the reader lines for nothing and hides how
# short the expression is.
#
# @example
#   # bad - hash that fits on one line
#   x = {
#     foo: 1,
#     bar: 2
#   }
#
#   # good
#   x = { foo: 1, bar: 2 }
#
#   # bad - array that fits on one line
#   x = [
#     1,
#     2,
#     3
#   ]
#
#   # good
#   x = [ 1, 2, 3 ]
#
#   # bad - backslash continuation that fits on one line
#   redirect_to \
#     users_path, notice: "Done"
#
#   # good
#   redirect_to users_path, notice: "Done"
#
#   # bad - parenthesized call that fits on one line
#   User.new(
#     name: "John"
#   )
#
#   # good
#   User.new(name: "John")
#
class RuboCop::Cop::Callbacksystems::CollapseMultilineExpression < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_hash(node)
    report_if_uncommented CollapsibleExpression.new(SingleLineLiteral.new(node, max_line_length, HASH_SHAPE)), node:
  end

  def on_array(node)
    report_if_uncommented CollapsibleExpression.new(SingleLineLiteral.new(node, max_line_length, ARRAY_SHAPE)), node:
  end

  def on_send(node)
    report_if_uncommented \
      CollapsibleExpression.new(RuboCop::Callbacksystems::Source::SingleLineCall.new(node, max_line_length)),
      node:
  end

  alias on_csend on_send

  private
    Shape = Data.define(:open, :close, :items)

    HASH_SHAPE = Shape.new(open: "{", close: "}", items: :children)
    ARRAY_SHAPE = Shape.new(open: "[", close: "]", items: :values)

    def report_if_uncommented(analysis, node:)
      report analysis if node.multiline? && !comments_within?(node)
    end

    def comments_within?(node)
      source_comments.any_within?(node)
    end

    class CollapsibleExpression
      MESSAGE = "This expression can fit on a single line."

      def initialize(single_line)
        @single_line = single_line
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(single_line.node, MESSAGE) { correct(it) } if single_line.fits?
      end

      private
        attr_reader :single_line

        def correct(corrector)
          corrector.replace(single_line.node, single_line.source)
        end
    end

    class SingleLineLiteral
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node, max_line_length, shape)
        @node = node
        @max_line_length = max_line_length
        @shape = shape
      end

      def fits?
        delimiter_match? && multiline? && no_multiline_items? && !carries_heredoc?(node) && fits_on_one_line?
      end

      def source
        @source ||= "#{shape.open} #{items_source} #{shape.close}"
      end

      private
        attr_reader :max_line_length, :shape

        def delimiter_match?
          node.loc.begin&.source == shape.open
        end

        def multiline?
          !node.single_line?
        end

        def no_multiline_items?
          items.all?(&:single_line?)
        end

        def items
          node.public_send(shape.items)
        end

        def fits_on_one_line?
          fits_on_line?(node, source, max_line_length)
        end

        def items_source
          items.map { it.source.strip }.join(", ")
        end
    end
end
