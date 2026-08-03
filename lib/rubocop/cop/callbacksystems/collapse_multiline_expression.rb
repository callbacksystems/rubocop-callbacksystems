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
#   # bad - only the marker of a heredoc belongs to the expression
#   PROBES = [
#     <<~SQL
#       select 1
#     SQL
#   ].freeze
#
#   # good - the body is written out again below the line that survives
#   PROBES = [ <<~SQL ].freeze
#     select 1
#   SQL
#
class RuboCop::Cop::Callbacksystems::CollapseMultilineExpression < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "This expression can fit on a single line."

  def on_hash(node)
    collapse LiteralCollapser.new(node, max_line_length, hash_shape, comments)
  end

  def on_array(node)
    collapse LiteralCollapser.new(node, max_line_length, array_shape, comments)
  end

  def on_send(node)
    collapse SendCollapser.new(node, max_line_length, comments)
  end

  alias on_csend on_send

  private
    delegate :comments, to: :processed_source, private: true

    def collapse(collapser)
      add_offense(collapser.node, message: MESSAGE) { collapser.apply(it) } if collapser.offense?
    end

    def max_line_length
      cop_config["MaxLineLength"]
    end

    def hash_shape
      Shape.new(open: "{", close: "}", items: :children)
    end

    def array_shape
      Shape.new(open: "[", close: "]", items: :values)
    end

    class LiteralCollapser
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node, max_line_length, shape, comments)
        @node = node
        @max_line_length = max_line_length
        @shape = shape
        @comments = comments
      end

      def offense?
        delimiter_match? && multiline? && no_multiline_items? && fits_on_one_line? && !carries_comment?
      end

      def collapsed
        @collapsed ||= shape.wrap(items_source)
      end

      def apply(corrector)
        corrector.replace(node, collapsed)
        bodies.relocate(corrector)
      end

      private
        attr_reader :max_line_length, :shape, :comments

        def delimiter_match?
          shape.opens?(node)
        end

        def multiline?
          !node.single_line?
        end

        def no_multiline_items?
          items.all?(&:single_line?)
        end

        def items
          shape.items_of(node)
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

        # One line cannot hold an own-line comment, so an expression carrying one
        # keeps the shape it has.
        def carries_comment?
          holds_comment?(node.source_range, comments)
        end

        # A heredoc's body outlives the collapse: only its marker sits inside
        # the expression, so the body is written out again below the line.
        def bodies
          RuboCop::Callbacksystems::HeredocBodies.new(node)
        end
    end

    # The bracket pair a literal collapses into, and how to reach the items
    # between them.
    class Shape < Data.define(:open, :close, :items)
      def opens?(node)
        node.loc.begin&.source == open
      end

      def items_of(node)
        node.public_send(items)
      end

      def wrap(inner)
        "#{open} #{inner} #{close}"
      end
    end

    class SendCollapser
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node, max_line_length, comments)
        @node = node
        @max_line_length = max_line_length
        @comments = comments
      end

      def offense?
        multiline? && collapsible_shape? && chain_collapsible? && fits_on_one_line? && !carries_comment?
      end

      def collapsible_shape?
        !block_call? && !operator_method? && !link_in_chain? && !chain_contains_blocks?
      end

      def collapsed
        @collapsed ||= "#{collapsed_receiver_part}#{node.method_name}#{args_suffix}"
      end

      def apply(corrector)
        corrector.replace(node, collapsed)
        bodies.relocate(corrector)
      end

      private
        attr_reader :max_line_length, :comments
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
              self.class.new(node.receiver, max_line_length, comments).collapsed
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

        # One line cannot hold an own-line comment, so a call carrying one keeps
        # the shape it has.
        def carries_comment?
          holds_comment?(node.source_range, comments)
        end

        # A heredoc's body outlives the collapse: only its marker sits inside
        # the call, so the body is written out again below the line.
        def bodies
          RuboCop::Callbacksystems::HeredocBodies.new(node)
        end
    end
end
