# Detects local variables that alias a method call that already reads as a name. Call the method directly or extract a
# well-named declarative method instead. A variable that names a computed expression (operator, block-pass, literal
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

  MESSAGE = "Variable `%<name>s` is unnecessary. Call the method directly or extract a well-named declarative method."

  def on_lvasgn(node)
    assignment = Assignment.new(node, processed_source.comments)
    add_offense(node, message: assignment.offense_message) { assignment.inline(it) } if assignment.offense?
  end

  private
    class Step < Data.define(:child, :parent)
      # These evaluate their first child before deciding; whatever comes after may never run.
      GATED = %i[and or if while until case case_match csend].freeze
      SKIPPABLE = %i[block numblock itblock resbody].freeze

      def deferred?
        skippable? || gated?
      end

      private
        def skippable?
          SKIPPABLE.include?(parent&.type)
        end

        def gated?
          GATED.include?(parent&.type) && !parent.children.first.equal?(child)
        end
    end

    class Assignment
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
        @variable_name = node.name
        @value = node.expression
      end

      def offense?
        aliases_named_call? && !conditional? && single_use? && !used_inside_nested_block? && !used_for_restoration?
      end

      def offense_message
        format(MESSAGE, name: variable_name)
      end

      # Only into the very next statement, where nothing runs in between and the evaluation order cannot change.
      def inline(corrector)
        if inlineable?
          corrector.remove(removal_range)
          corrector.replace(reference, inlined_source)
        end
      end

      private
        attr_reader :node, :comments, :variable_name, :value

        def aliases_named_call?
          value&.type?(:call) && !computed_expression? && !value.multiline?
        end

        def computed_expression?
          value.operator_method? || value.arguments.any?(&:block_pass_type?) || value.receiver&.type?(:array, :hash)
        end

        def conditional?
          node.each_ancestor(:if, :while, :until, :case, :and, :or).any?
        end

        def single_use?
          enclosing_scope && !reassigned? && references.size == 1
        end

        def enclosing_scope
          @enclosing_scope ||= node.each_ancestor(:any_def, :any_block).first
        end

        def reassigned?
          other_occurrences.any?(&:lvasgn_type?)
        end

        def other_occurrences
          @other_occurrences ||= enclosing_scope.each_descendant(:lvar, :lvasgn).select do |descendant|
            descendant.name == variable_name && descendant != node
          end
        end

        def references
          @references ||= other_occurrences.select(&:lvar_type?)
        end

        def used_inside_nested_block?
          references.first.each_ancestor(:any_block).any? { it != enclosing_scope }
        end

        def used_for_restoration?
          references.first.each_ancestor(:ensure, :resbody).any?
        end

        def inlineable?
          reads_the_reference? && unconditionally_reached?
        end

        def reads_the_reference?
          next_statement&.each_node(:lvar)&.any? { it.equal?(reference) }
        end

        def next_statement
          if node.parent&.begin_type?
            siblings = node.parent.children
            siblings[siblings.index(node) + 1]
          end
        end

        def reference
          references.first
        end

        # Behind a short-circuit, a branch, a block or a safe navigation the call would stop happening where the
        # assignment ran it every time.
        def unconditionally_reached?
          steps_to_next_statement.none?(&:deferred?)
        end

        def steps_to_next_statement
          nodes = [ reference, *reference.each_ancestor.take_while { it != next_statement } ]
          nodes.map { Step.new(child: it, parent: it.parent) }
        end

        # Stops short of a comment in the gap: it was written about the statement that survives.
        def removal_range
          range_ending_at_first_comment(assignment_gap, comments)
        end

        def assignment_gap
          node.source_range.with(end_pos: next_statement.source_range.begin_pos)
        end

        # In a receiver or argument position, `find_account "id"` would swallow the following `.method` or comma, so the
        # arguments get parentheses.
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
