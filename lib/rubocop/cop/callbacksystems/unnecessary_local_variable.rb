# Detects local variables that alias a method call that already reads as a name.
# Call the method directly or extract a well-named declarative method instead.
# A variable that names a computed expression (operator, block-pass, literal
# receiver) or a multiline call is left alone: there the name does real work.
#
# @example
#   # bad - variable just aliases a method call
#   directory = forbidden_directory
#   add_offense(node) if directory
#
#   # good - call the method directly
#   add_offense(node) if forbidden_directory
#
#   # ok - variable names a computed expression
#   valid_values = options.map(&:value)
#   answer.errors.add(:base) if (submitted_values - valid_values).any?
#
#   # ok - call spans multiple lines
#   record = relation.create! \
#     type: "Report",
#     data: {}
#   record.deliver
#
#   # ok - variable used multiple times
#   user = find_user
#   user.activate
#   user.notify
#
#   # ok - variable used inside a block (may be mutated across iterations)
#   result = Set.new
#   items.each { |item| result << item }
#
#   # ok - assignment in conditional
#   if user = find_user
#     user.activate
#   end
#
#   # ok - variable reassigned
#   current = first
#   current = current.next while current
#
class RuboCop::Cop::Callbacksystems::UnnecessaryLocalVariable < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @local_variables = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(processed_source.ast)
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
  end

  def on_lvasgn(node)
    report Assignment.new(node, @local_variables, @source_comments)
  end

  private
    class Assignment
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Variable `%<name>s` is unnecessary. Call the method directly or extract a well-named declarative " \
        "method."

      def initialize(node, local_variables, source_comments)
        @node = node
        @local_variables = local_variables
        @source_comments = source_comments
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message, correcting: inlineable?) { correct(it) } if unnecessary?
      end

      private
        attr_reader :node, :local_variables, :source_comments

        def unnecessary?
          aliases_named_call? && !conditional? && single_use? && !used_inside_nested_block? && !used_for_restoration?
        end

        def aliases_named_call?
          value&.type?(:call) && !computed_expression? && !value.multiline?
        end

        def value
          node.expression
        end

        def computed_expression?
          value.operator_method? || value.arguments.any?(&:block_pass_type?) || literal_receiver?
        end

        def literal_receiver?
          value.receiver&.then { it.type?(:array, :hash) || it.recursive_literal? }
        end

        def conditional?
          node.each_ancestor(:if, :while, :until, :case, :and, :or).any?
        end

        def single_use?
          enclosing_scope && !reassigned? && references.one?
        end

        def enclosing_scope
          @enclosing_scope ||= enclosing_scope_of(node)
        end

        def reassigned?
          other_occurrences.any? { it.type?(:lvasgn, :match_var) }
        end

        def other_occurrences
          @other_occurrences ||= local_variables.named(node.name, around: node).reject { it.equal?(node) }
        end

        def references
          @references ||= other_occurrences.select(&:lvar_type?)
        end

        def used_inside_nested_block?
          reference.each_ancestor(:any_block).any? { it != enclosing_scope }
        end

        def reference
          references.first
        end

        def used_for_restoration?
          reference.each_ancestor(:ensure, :resbody).any?
        end

        def message
          format(MESSAGE, name: node.name)
        end

        # The next statement removes intervening work; its evaluation path must also keep the call eager and ordered.
        def inlineable?
          nodes_in(next_statement, :lvar).any? { it.equal?(reference) } && !read_by_another_assignment? &&
            !carries_heredoc?(node) && relocation_preserves_order? && removal_uncommented?
        end

        def next_statement
          node.right_sibling if node.parent.begin_type?
        end

        # Two corrections on one line would overwrite each other, so this one waits for the pass that follows.
        def read_by_another_assignment?
          reference.each_ancestor(:lvasgn).any?
        end

        def relocation_preserves_order?
          RuboCop::Callbacksystems::Execution::EagerEvaluationPath.new(reference, within: next_statement)
            .preserves_order?
        end

        def removal_uncommented?
          !source_comments.any_within?(node.source_range.with(end_pos: next_statement.source_range.begin_pos))
        end

        def correct(corrector)
          corrector.remove(node.source_range.with(end_pos: next_statement.source_range.begin_pos))
          replace_expression(corrector, reference, with: inlined_source)
        end

        # Bare arguments at the read would swallow the following `.method` or comma, so they get parentheses.
        def inlined_source
          if value.arguments? && !value.parenthesized?
            "#{call_source_through_selector}(#{value.arguments.map(&:source).join(", ")})"
          else
            value.source
          end
        end

        def call_source_through_selector
          value.source_range.with(end_pos: value.loc.selector.end_pos).source
        end
    end
end
