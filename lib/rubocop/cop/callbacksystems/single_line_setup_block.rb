# Asks for `{ }` over `do end` on a single-line setup or teardown block. The
# `do end` form is the shape of a body with several lines, so wrapping one
# statement in it spends two lines on a body that never grew.
#
# @example
#   # bad
#   setup do
#     @user = users(:bruno)
#   end
#
#   # good
#   setup { @user = users(:bruno) }
#
#   # good (multi-line is fine with do/end)
#   setup do
#     @user = users(:bruno)
#     @account = accounts(:callback)
#   end
#
class RuboCop::Cop::Callbacksystems::SingleLineSetupBlock < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
  end

  def on_block(node)
    report SetupBlock.new(node, @source_comments)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class SetupBlock
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      MESSAGE = "Use `%<method>s { ... }` for single-line blocks instead of `do ... end`."

      # @!method setup_or_teardown_block?(node)
      def_node_matcher :setup_or_teardown_block?, <<~PATTERN
        (any_block (send nil? ${:setup :teardown} ...) ...)
      PATTERN

      def initialize(node, source_comments)
        @node = node
        @source_comments = source_comments
      end

      def offense
        offense_for_block if expanded_one_liner?
      end

      private
        attr_reader :node, :source_comments

        def expanded_one_liner?
          setup_or_teardown_block?(node) && !node.braces? && node.body&.single_line? && statements_in(node.body).one?
        end

        def offense_for_block
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: correctable?) { correct(it) }
        end

        def message
          format(MESSAGE, method: node.method_name)
        end

        # Braces bind tighter than command-style arguments, so a multiline command stays untouched until its comments
        # and indentation can be preserved. A single-line command can become an explicit argument list.
        def correctable?
          comments_movable? && !carries_heredoc?(node.body) &&
            (node.send_node.arguments.empty? || node.send_node.parenthesized? || node.send_node.single_line?)
        end

        # One prose comment has an unambiguous home after the compact block. Several comments encode a layout of their
        # own, and tooling directives can change meaning when moved, so neither is rewritten.
        def comments_movable?
          comments_on_block_lines.size <= 1 && comments_on_block_lines.none? { tooling_comment?(it) }
        end

        def comments_on_block_lines
          @comments_on_block_lines ||= source_comments.on_lines(node.first_line..node.last_line)
        end

        def correct(corrector)
          corrector.replace(node, "#{call_source} { #{parameters}#{node.body.source.strip} }")
        end

        def call_source
          if node.send_node.arguments? && !node.send_node.parenthesized?
            "#{node.method_name}(#{call_arguments_source})"
          else
            node.send_node.source
          end
        end

        def call_arguments_source
          node.send_node.first_argument.source_range.join(node.send_node.last_argument.source_range).source
        end

        def parameters
          "#{node.arguments.source} " unless node.arguments.empty?
        end
    end
end
