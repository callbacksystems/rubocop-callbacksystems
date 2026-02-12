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
class RuboCop::Cop::Callbacksystems::CollapseMultilineExpression < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "This expression can fit on a single line."

  def on_hash(node)
    collapser = HashCollapser.new(node, max_line_length)

    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node.source_range, collapser.collapsed)
      end
    end
  end

  def on_array(node)
    collapser = ArrayCollapser.new(node, max_line_length)

    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node.source_range, collapser.collapsed)
      end
    end
  end

  def on_send(node)
    collapser = SendCollapser.new(node, max_line_length)

    if collapser.offense?
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node.source_range, collapser.collapsed)
      end
    end
  end

  private
    def max_line_length
      cop_config["MaxLineLength"] || 120
    end

    class HashCollapser
      def initialize(node, max_line_length)
        @node = node
        @max_line_length = max_line_length
      end

      def offense?
        braced? && multiline? && no_multiline_pairs? && fits_on_one_line?
      end

      def collapsed
        @collapsed ||= "{ #{pairs_source} }"
      end

      private
        attr_reader :node, :max_line_length

        def braced?
          node.loc.begin&.source == "{"
        end

        def multiline?
          node.first_line != node.last_line
        end

        def no_multiline_pairs?
          node.pairs.none? { |pair| pair.first_line != pair.last_line }
        end

        def fits_on_one_line?
          node.loc.column + collapsed.length + suffix_length <= max_line_length
        end

        def suffix_length
          last_line = node.loc.end.source_line
          last_line.length - node.loc.end.column - 1
        end

        def pairs_source
          node.pairs.map { |pair| pair.source.strip }.join(", ")
        end
    end

    class ArrayCollapser
      def initialize(node, max_line_length)
        @node = node
        @max_line_length = max_line_length
      end

      def offense?
        bracket_array? && multiline? && no_multiline_elements? && fits_on_one_line?
      end

      def collapsed
        @collapsed ||= "[ #{elements_source} ]"
      end

      private
        attr_reader :node, :max_line_length

        def bracket_array?
          node.loc.begin&.source == "["
        end

        def multiline?
          node.first_line != node.last_line
        end

        def no_multiline_elements?
          node.values.none? { |element| element.first_line != element.last_line }
        end

        def fits_on_one_line?
          node.loc.column + collapsed.length + suffix_length <= max_line_length
        end

        def suffix_length
          last_line = node.loc.end.source_line
          last_line.length - node.loc.end.column - 1
        end

        def elements_source
          node.values.map { |element| element.source.strip }.join(", ")
        end
    end

    class SendCollapser
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

        def multiline?
          node.first_line != node.last_line
        end

        def block_call?
          any_block_type?(node.parent)
        end

        def operator_method?
          node.operator_method?
        end

        def link_in_chain?
          node.parent&.send_type? && node.equal?(node.parent.receiver)
        end

        def chain_contains_blocks?
          current = node.receiver

          while current
            return true if any_block_type?(current)

            current = current.send_type? ? current.receiver : nil
          end

          false
        end

        def any_block_type?(ast_node)
          ast_node&.block_type? || ast_node&.numblock_type? || ast_node&.itblock_type?
        end

        def chain_collapsible?
          chain_sends.all? { |send_node| send_args_single_line?(send_node) }
        end

        def chain_sends
          [ node ].tap do |sends|
            current = node.receiver

            while current&.send_type?
              sends << current
              current = current.receiver
            end
          end
        end

        def send_args_single_line?(send_node)
          send_node.arguments.all? { |arg| argument_single_line?(arg) }
        end

        def argument_single_line?(arg)
          return arg.children.none? { |child| child.first_line != child.last_line } if implicit_hash?(arg)

          arg.first_line == arg.last_line
        end

        def fits_on_one_line?
          collapsed.count("\n").zero? && node.loc.column + collapsed.length <= max_line_length
        end

        def collapsed_receiver_part
          return "" unless node.receiver

          dot = node.loc.dot&.source || "."
          receiver_collapsed = if node.receiver.send_type?
            self.class.new(node.receiver, max_line_length).collapsed
          else
            node.receiver.source.strip
          end
          "#{receiver_collapsed}#{dot}"
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
          node.arguments.flat_map { |arg| argument_sources(arg) }.join(", ")
        end

        def argument_sources(arg)
          return arg.children.map { |child| child.source.strip } if implicit_hash?(arg)

          [ arg.source.strip ]
        end

        def implicit_hash?(arg)
          arg.hash_type? && !arg.loc.begin
        end
    end
end
