# Prefers backslash line continuation over parentheses for multiline method calls. Single-line calls may use parentheses
# for constructors.
#
# @example
#   # bad - multiline with parentheses
#   claim = Account::Invitation::Claim.new(
#     invitation: invitations(:bruno),
#     name: "Test User"
#   )
#
#   # good - multiline with backslash
#   claim = Account::Invitation::Claim.new \
#     invitation: invitations(:bruno),
#     name: "Test User"
#
#   # good - single-line constructor
#   user = User.new(name: "Bruno")
#
#   # good - method call without parentheses
#   redirect_to account_path, notice: t(".success")
#
#   # good - nested call (can't use backslash inside another call)
#   update!(time_block: Model.find_or_create_by!(
#     starts_at: starts_at, ends_at: ends_at
#   ))
#
#   # good - block disambiguation (without parens block goes to outer method)
#   concat(tag.div do
#     content
#   end)
#
#   # good - first argument shares the opening line (only the trailing hash wraps)
#   selections.add(rule: rule, params: {
#     starts_at: starts_at
#   })
#
class RuboCop::Cop::Callbacksystems::PreferBackslashContinuation < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `\\` for line continuation instead of wrapping arguments in parentheses."

  def on_send(node)
    call = MethodCall.new(node, processed_source)
    add_offense(node.loc.begin, message: MESSAGE) { call.autocorrect(it) } if call.offense?
  end

  alias on_csend on_send

  private
    class MethodCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, processed_source)
        @node = node
        @processed_source = processed_source
      end

      def offense?
        node.parenthesized? && multiline_send?(node) && !allowed?
      end

      def autocorrect(corrector)
        if correctable?
          lift_displaced_comments(corrector)
          corrector.replace(node.loc.begin, " \\")
          corrector.remove(trailing_parenthesis_range)
        end
      end

      private
        attr_reader :node, :processed_source

        def multiline_send?(send_node)
          send_node.arguments? && send_node.loc.begin && send_node.loc.end && send_node.loc.begin.line != send_node.loc.end.line
        end

        def allowed?
          inside_other_expression? || unconvertible_arguments?
        end

        def inside_other_expression?
          nested_in_call? || inside_backslash_continuation? || chained_method_receiver? || inside_collection_literal?
        end

        def nested_in_call?
          node.each_ancestor(:send).any? do |ancestor|
            ancestor.arguments.any? { it == node || it.each_descendant.include?(node) }
          end
        end

        def inside_backslash_continuation?
          previous_line(node.loc.begin.line)&.rstrip&.end_with?("\\")
        end

        def previous_line(line)
          node.source_range.source_buffer.source.lines[line - 2] if line > 1
        end

        def chained_method_receiver?
          node.parent&.call_type? && node.parent.receiver == node
        end

        def inside_collection_literal?
          node.each_ancestor(:hash, :array).any?
        end

        def unconvertible_arguments?
          argument_has_block? || contains_multiline_call? || leading_braced_hash? || first_argument_on_opening_line?
        end

        def argument_has_block?
          direct_block_argument? || nested_block_in_arguments?
        end

        def direct_block_argument?
          node.arguments.any? { block_or_send_with_block?(it) }
        end

        def block_or_send_with_block?(arg)
          any_block_type?(arg) || (arg.send_type? && arg.parent&.block_type?)
        end

        def nested_block_in_arguments?
          node.arguments.any? { it.each_descendant(:any_block).any? }
        end

        def contains_multiline_call?
          node.each_descendant(:send).any? { multiline_send?(it) }
        end

        def leading_braced_hash?
          node.first_argument.hash_type? && node.first_argument.braces?
        end

        def first_argument_on_opening_line?
          node.first_argument.source_range.line == node.loc.begin.line
        end

        def correctable?
          !last_argument_has_heredoc?
        end

        def last_argument_has_heredoc?
          node.last_argument.each_node(:any_str).any?(&:heredoc?)
        end

        # The backslash would swallow a comment before the first argument, and the closing parenthesis takes whatever
        # sits in front of it.
        def lift_displaced_comments(corrector)
          RuboCop::Callbacksystems::LiftedComments.new(node, displaced_comments).lift(corrector)
          leading_comments.each { corrector.remove(line_removal_range_for(it)) }
        end

        def displaced_comments
          leading_comments + comments_in(trailing_parenthesis_range, processed_source.comments)
        end

        def leading_comments
          comments_in(continuation_range, processed_source.comments)
        end

        def continuation_range
          node.loc.begin.join(node.first_argument.source_range.begin)
        end

        def trailing_parenthesis_range
          node.last_argument.source_range.end.join(node.loc.end)
        end
    end
end
