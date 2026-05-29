# Detects private methods that only delegate to a same-named method on a simple
# receiver (`def size; node.size; end`). The `delegate` macro says it declaratively.
# Rails/Delegate covers public delegations but skips private ones (the macro defines
# public methods unless told otherwise), so the private case is caught here.
#
# The autocorrection folds the method into an existing same-receiver
# `delegate ... private: true` when one is present, keeping them on one line;
# otherwise it writes a fresh macro beside the section's other declarations.
#
# @example
#   # bad - hand-written private delegation
#   private
#     delegate :name, to: :node, private: true
#
#     def size
#       node.size
#     end
#
#   # good - folded into the existing delegate
#   private
#     delegate :name, :size, to: :node, private: true
#
class RuboCop::Cop::Callbacksystems::PreferDelegate < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use the `delegate` macro instead of a hand-written delegation to `%<receiver>s`."

  def on_def(node)
    delegation = ManualDelegation.new(node)
    add_offense(node, message: delegation.offense_message) { delegation.correct(it) } if delegation.offense?
  end

  private
    class ManualDelegation
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        private_method?(node) && node.arguments.empty? && delegates_to_same_name?
      end

      def offense_message
        format(MESSAGE, receiver: receiver_name)
      end

      def correct(corrector)
        Conversion.new(node, receiver_name).apply(corrector)
      end

      private
        attr_reader :node
        delegate :body, to: :node, private: true

        def delegates_to_same_name?
          body&.send_type? && body.method?(node.method_name) && body.arguments.empty? && simple_receiver?
        end

        def simple_receiver?
          bare_send?(body.receiver) && body.receiver.arguments.empty?
        end

        def receiver_name
          body.receiver.method_name
        end
    end

    # Rewrites the method as the delegate macro: folded into a same-receiver
    # `delegate ... private: true` if one exists, otherwise a new macro placed after
    # the section's declarations (attr_reader/delegate) or its `private` modifier.
    class Conversion
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, receiver)
        @node = node
        @receiver = receiver
      end

      def apply(corrector)
        sibling = same_receiver_delegate
        if sibling
          corrector.insert_before(sibling.last_argument, ":#{node.method_name}, ")
        else
          corrector.insert_after(anchor, "\n#{macro_indent}delegate :#{node.method_name}, to: :#{receiver}, private: true")
        end
        corrector.remove(removal_range)
      end

      private
        attr_reader :node, :receiver

        def same_receiver_delegate
          container_statements.find { private_delegate_to_receiver?(it) }
        end

        def container_statements
          statements_in(enclosing_class_or_module_of(node)&.body)
        end

        def private_delegate_to_receiver?(statement)
          statement.send_type? && statement.method?(:delegate) &&
            options(statement)&.then { target(it) == receiver && private?(it) }
        end

        def options(statement)
          statement.last_argument if statement.last_argument&.hash_type?
        end

        def target(options)
          value(options, :to)&.then { it.value if it.sym_type? }
        end

        def value(options, key)
          options.pairs.find { it.key.sym_type? && it.key.value == key }&.value
        end

        def private?(options)
          value(options, :private)&.true_type? || false
        end

        def anchor
          declarations.last || private_modifier
        end

        def declarations
          preceding_statements.select { declaration?(it) }
        end

        def preceding_statements
          container_statements.take_while { it != node }
        end

        def declaration?(statement)
          bare_send?(statement) && %i[attr_reader attr_accessor delegate].include?(statement.method_name)
        end

        def private_modifier
          preceding_statements.find { visibility_modifier_of(it) == :private }
        end

        def macro_indent
          " " * node.source_range.column
        end

        # The method's own lines plus the blank line above it, so removing the method
        # does not leave a stray blank where it used to sit.
        def removal_range
          range = line_removal_range_for(node)
          blank_line_above(range) || range
        end

        def blank_line_above(range)
          source = range.source_buffer.source
          newline = range.begin_pos - 1
          if newline >= 0 && source[newline] == "\n"
            line_start = (source.rindex("\n", newline - 1) || -1) + 1
            range.with(begin_pos: line_start) if source[line_start...newline].match?(/\A[ \t]*\z/)
          end
        end
    end
end
