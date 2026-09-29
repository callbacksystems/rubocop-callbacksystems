# The one-line form of a call and whether the call belongs on it. Cops measuring this apart end up giving the same call
# contradictory advice, so they read it here.
class RuboCop::Callbacksystems::Source::SingleLineCall
  include RuboCop::Callbacksystems::Helpers

  attr_reader :node

  def initialize(node, max_line_length)
    @node = node
    @max_line_length = max_line_length
  end

  def fits?
    multiline? && !stays_multiline? && chain_collapsible? && fits_on_one_line?
  end

  def source
    @source ||= CollapsedSource.new(node).value
  end

  private
    attr_reader :max_line_length
    delegate :operator_method?, to: :node, private: true

    def multiline?
      !node.single_line?
    end

    def stays_multiline?
      block_call? || operator_method? || link_in_chain? || chain_contains_blocks? || carries_heredoc?(node)
    end

    def block_call?
      any_block_type?(node.parent)
    end

    def link_in_chain?
      node.parent&.call_type? && node.equal?(node.parent.receiver)
    end

    def chain_contains_blocks?(current = node.receiver)
      ReceiverPath.new(current).any? { any_block_type?(it) }
    end

    def chain_collapsible?
      chain_sends.all? { send_args_single_line?(it) }
    end

    def chain_sends
      [ node, *ReceiverPath.new(node.receiver).take_while(&:call_type?) ]
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
      source.exclude?("\n") && fits_on_line?(node, source, max_line_length)
    end

    # The receiver nodes leading inward from a call, walked without depending on Ruby's call stack.
    class ReceiverPath
      include Enumerable

      def initialize(node)
        @node = node
      end

      def each
        if block_given?
          current = node
          while current
            yield current
            current = current.call_type? ? current.receiver : nil
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node
    end

    # The collapsed source of a receiver call chain, assembled from its innermost call outward in one pass.
    class CollapsedSource
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def value
        fragments.join
      end

      private
        attr_reader :node

        def fragments
          calls.reverse_each.with_index.map do |call, index|
            CallFragment.new(call, leading_receiver: index.zero?).value
          end
        end

        def calls
          current = node
          [ current ].then do |chain|
            while current.receiver&.call_type? && !current.receiver.operator_method?
              current = current.receiver
              chain << current
            end
            chain
          end
        end
    end

    class CallFragment
      include RuboCop::Callbacksystems::Helpers

      def initialize(call, leading_receiver:)
        @call = call
        @leading_receiver = leading_receiver
      end

      def value
        [ receiver_source, dot_source, call.method_name, arguments_suffix ].compact.join
      end

      private
        attr_reader :call, :leading_receiver

        # An index or operator call has no selector to rebuild from, so it stays as written.
        def receiver_source
          call.receiver.source.strip if leading_receiver && call.receiver
        end

        def dot_source
          call.loc.dot.source if call.receiver
        end

        def arguments_suffix
          if parenthesized_once_collapsed?
            "(#{arguments_joined})"
          elsif call.arguments?
            " #{arguments_joined}"
          else
            ""
          end
        end

        def parenthesized_once_collapsed?
          # A backslash continuation is what lets a builder call go without parentheses, so they come back on collapse.
          call.parenthesized? || (call.arguments? && builder_method?(call))
        end

        def arguments_joined
          call.arguments.flat_map { sources_of(it) }.join(", ")
        end

        def sources_of(argument)
          return argument.children.map { it.source.strip } if implicit_hash?(argument)

          [ argument.source.strip ]
        end

        def implicit_hash?(argument)
          argument.hash_type? && !argument.loc.begin
        end
    end
end
