# A `private` keyword with nothing after it declares a section that holds
# nothing. Remove it and let the class end where it ends.
#
# The correction stays away when another expression observes the value of the
# class or module definition: `private` returns `nil`, while the statement above
# it may return something else.
#
# @example
#   # bad
#   class Order
#     def total
#     end
#
#     private
#   end
#
#   # good
#   class Order
#     def total
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::EmptyPrivateSection < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report PrivateSection.new(node, trailing_comment: trailing_comment_on(node))
  end

  alias on_csend on_send

  private
    def trailing_comment_on(node)
      RuboCop::Callbacksystems::Source::Comments.for(processed_source).trailing_comment_on(node.last_line)
    end

    class PrivateSection
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Remove the empty `private` section."

      def initialize(node, trailing_comment:)
        @node = node
        @trailing_comment = trailing_comment
      end

      def offense
        if empty?
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: correctable?) do |corrector|
            correct(corrector)
          end
        end
      end

      private
        attr_reader :node, :trailing_comment

        def empty?
          private_modifier? && closes_enclosing_body?
        end

        def private_modifier?
          visibility_modifier_of(node) == :private
        end

        def closes_enclosing_body?
          statements_in(enclosing_body).last.equal?(node)
        end

        # `enclosing_body_for` reports only multi-statement bodies, and a body of just the modifier has one statement.
        def enclosing_body
          enclosing_definition_of(node)&.body
        end

        def correctable?
          definition_result_discarded? && !moves_tooling_comment?
        end

        def definition_result_discarded?
          RuboCop::Callbacksystems::Execution::DiscardedExpression.new(enclosing_definition_of(node)).discarded?
        end

        def moves_tooling_comment?
          trailing_comment && tooling_comment?(trailing_comment)
        end

        def correct(corrector)
          if inline_removal_range && trailing_comment
            corrector.replace(inline_removal_range.join(trailing_comment.source_range), standing_comment)
          else
            corrector.remove(statement_removal_range_for(node))
          end
        end

        def inline_removal_range
          @inline_removal_range ||= inline_statement_removal_range_for(node)
        end

        def standing_comment
          "\n#{line_indentation}#{trailing_comment.text}"
        end

        def line_indentation
          node.source_range.source_line[/\A[ \t]*/]
        end
    end
end
