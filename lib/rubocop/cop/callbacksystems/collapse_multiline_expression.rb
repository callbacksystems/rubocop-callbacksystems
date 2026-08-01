# Detects multiline expressions that can fit on a single line and collapses them.
# Applies to hash literals, array literals, and method calls with backslash
# continuation or parenthesized arguments.
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

  MESSAGE = "This expression can fit on a single line."

  HASH_SHAPE = { open: "{", close: "}", items: :children }.freeze
  ARRAY_SHAPE = { open: "[", close: "]", items: :values }.freeze

  def on_hash(node)
    collapser = LiteralCollapser.new(node, max_line_length, HASH_SHAPE)
    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, collapser.collapsed)
      end
    end
  end

  def on_array(node)
    collapser = LiteralCollapser.new(node, max_line_length, ARRAY_SHAPE)
    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, collapser.collapsed)
      end
    end
  end

  def on_send(node)
    collapser = SendCollapser.new(node, max_line_length)

    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, collapser.collapsed)
      end
    end
  end

  alias on_csend on_send

  private
    def max_line_length
      cop_config["MaxLineLength"]
    end

    class LiteralCollapser
      def initialize(node, max_line_length, shape)
        @node = node
        @max_line_length = max_line_length
        @shape = shape
      end

      def offense?
        delimiter_match? && multiline? && no_multiline_items? && fits_on_one_line?
      end

      def collapsed
        @collapsed ||= "#{shape[:open]} #{items_source} #{shape[:close]}"
      end

      private
        attr_reader :node, :max_line_length, :shape

        def delimiter_match?
          node.loc.begin&.source == shape[:open]
        end

        def multiline?
          !node.single_line?
        end

        def no_multiline_items?
          items.all?(&:single_line?)
        end

        def items
          node.public_send(shape[:items])
        end

        def fits_on_one_line?
          node.loc.column + collapsed.length + suffix_length <= max_line_length
        end

        def items_source
          items.map { it.source.strip }.join(", ")
        end

        def suffix_length
          node.loc.end.source_line.length - node.loc.end.column - 1
        end
    end

    class SendCollapser
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, max_line_length)
        @node = node
        @max_line_length = max_line_length
      end

      def offense?
        multiline? && !block_call? && !operator_method? && !link_in_chain? && !chain_contains_blocks? && chain_collapsible? && fits_on_one_line?
      end

      def collapsed
        @collapsed ||= "#{collapsed_receiver_part}#{node.method_name}#{args_suffix}"
      end

      private
        attr_reader :node, :max_line_length
        delegate :operator_method?, to: :node, private: true

        def multiline?
          !node.single_line?
        end

        def block_call?
          any_block_type?(node.parent)
        end

        def link_in_chain?
          node.parent&.send_type? && node.equal?(node.parent.receiver)
        end

        def chain_contains_blocks?(current = node.receiver)
          if current
            any_block_type?(current) || (current.send_type? && chain_contains_blocks?(current.receiver))
          else
            false
          end
        end

        def chain_collapsible?
          chain_sends.all? { send_args_single_line?(it) }
        end

        def chain_sends
          [ node, *receiver_send_chain_from(node.receiver) ]
        end

        def receiver_send_chain_from(current)
          if current&.send_type?
            [ current, *receiver_send_chain_from(current.receiver) ]
          else
            []
          end
        end

        def send_args_single_line?(send_node)
          send_node.arguments.all? { argument_single_line?(it) }
        end

        def argument_single_line?(arg)
          return arg.children.all?(&:single_line?) if implicit_hash?(arg)

          arg.single_line?
        end

        def implicit_hash?(arg)
          arg.hash_type? && !arg.loc.begin
        end

        def fits_on_one_line?
          !collapsed.include?("\n") && node.loc.column + collapsed.length <= max_line_length
        end

        def collapsed_receiver_part
          if node.receiver
            dot = node.loc.dot&.source || "."
            receiver_collapsed = if node.receiver.send_type?
              self.class.new(node.receiver, max_line_length).collapsed
            else
              node.receiver.source.strip
            end
            "#{receiver_collapsed}#{dot}"
          else
            ""
          end
        end

        def args_suffix
          if node.parenthesized?
            "(#{arguments_joined})"
          elsif node.arguments?
            " #{arguments_joined}"
          else
            ""
          end
        end

        def arguments_joined
          node.arguments.flat_map { sources_of(it) }.join(", ")
        end

        def sources_of(arg)
          return arg.children.map { it.source.strip } if implicit_hash?(arg)

          [ arg.source.strip ]
        end
    end
end
