# Detects a fixture assigned to a variable the test reads once. The variable
# spends a line on a name for a record the fixture call already names, so the
# test reads shorter with the call standing where the variable was.
#
# @example
#   # bad - fixture stored in variable but only used once
#   test "validates user" do
#     user = users(:john)
#     assert user.valid?
#   end
#
#   # good - inline the fixture
#   test "validates user" do
#     assert users(:john).valid?
#   end
#
#   # good - variable used multiple times
#   test "validates user" do
#     user = users(:john)
#     assert user.valid?
#     assert user.name.present?
#   end
#
class RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::Testing::CopHelpers
  extend RuboCop::Cop::AutoCorrector

  def external_dependency_checksum
    RuboCop::Callbacksystems::Source::FilesChecksum.for \
      "**/test/fixtures/**/*.yml", root: project_root, include_contents: false
  end

  def on_block(node)
    report_each SingleUseFixtures.new(node.body) if test_block?(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class SingleUseFixtures
      include RuboCop::Callbacksystems::Helpers

      def initialize(body)
        @body = body
      end

      def each_offense(&block)
        test_variables.assignments.filter_map do |assignment|
          FixtureAssignment.new(assignment, usage: test_variables.usage_of(assignment)).offense
        end.each(&block)
      end

      private
        attr_reader :body

        def test_variables
          @test_variables ||= TestVariables.new(body)
        end
    end

    class FixtureAssignment
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Fixture `%<fixture>s` is assigned to `%<variable>s` but only used once. Inline it instead."

      def initialize(node, usage:)
        @node = node
        @usage = usage
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message, correcting: inlineable?) { correct(it) } if
          fixture.valid? && sole_read
      end

      private
        attr_reader :node, :usage

        def fixture
          @fixture ||= RuboCop::Callbacksystems::Testing::FixtureCall.new(node.expression)
        end

        # A read inside a block of the test may run more than once, so the call is not the same as the variable there.
        def sole_read
          defined?(@sole_read) ? @sole_read : @sole_read = usage.sole_read
        end

        def message
          format(MESSAGE, fixture: fixture.signature, variable: node.name)
        end

        # Running anything between the lookup and its use can make moving that lookup observable, so those cases stay as
        # diagnostics for a human.
        def inlineable?
          usage.direct? && assignment_owns_its_lines? && usage.lookup_order_preserved?
        end

        def assignment_owns_its_lines?
          line_removal_range_for(node).source.strip == node.source
        end

        def correct(corrector)
          corrector.remove(line_removal_range_for(node))
          replace_expression(corrector, sole_read, with: fixture.signature)
        end
    end

    # Local-variable use, statement position and deferred captures indexed once for one test body.
    class TestVariables
      include RuboCop::Callbacksystems::Helpers

      def initialize(body)
        @body = body
      end

      def assignments
        @assignments ||= RuboCop::Callbacksystems::Execution::Immediate.new(body).nodes_of_type(:lvasgn)
      end

      def usage_of(assignment)
        VariableUsage.new \
          assignment,
          occurrences: occurrences.named(assignment.name, around: assignment),
          deferred_variables:,
          position: position_of(assignment)
      end

      private
        attr_reader :body

        def occurrences
          @occurrences ||= RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(body)
        end

        def deferred_variables
          @deferred_variables ||= RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)
        end

        def position_of(assignment)
          StatementPosition.new(test_scope, next_statements.fetch(assignment, nil), next_statements.key?(assignment))
        end

        def test_scope
          @test_scope ||= body.each_ancestor(:any_block).first
        end

        def next_statements
          @next_statements ||= {}.compare_by_identity.tap do |index|
            statements = statements_in(body)
            statements.each_with_index { |statement, position| index[statement] = statements[position + 1] }
          end
        end
    end

    # The reads and writes belonging to one fixture assignment in its test's lexical scope.
    class VariableUsage
      delegate :direct?, to: :position

      def initialize(node, occurrences:, deferred_variables:, position:)
        @node = node
        @occurrences = occurrences
        @deferred_variables = deferred_variables
        @position = position
      end

      def lookup_order_preserved?
        read = sole_read

        read && next_statement &&
          RuboCop::Callbacksystems::Execution::EagerEvaluationPath.new(read, within: next_statement).preserves_order?
      end

      def sole_read
        reads.first if reads.one? && stable?
      end

      private
        attr_reader :node, :occurrences, :deferred_variables, :position
        delegate :test_scope, :next_statement, to: :position, private: true

        def reads
          @reads ||= occurrences.select(&:lvar_type?)
        end

        def stable?
          !reassigned_before_read? && !repeated_in_test? && deferred_variables.exclude?(node.name)
        end

        def reassigned_before_read?
          occurrences.any? do |occurrence|
            occurrence.type?(:lvasgn, :match_var) && !occurrence.equal?(node) &&
              occurrence.source_range.begin_pos < reads.first.source_range.begin_pos
          end
        end

        def repeated_in_test?
          [ node, reads.first ].any? do |occurrence|
            occurrence.each_ancestor.take_while { !it.equal?(test_scope) }.any? do |ancestor|
              ancestor.type?(:any_block, :while, :while_post, :until, :until_post, :for)
            end
          end
        end
    end

    class StatementPosition < Data.define(:test_scope, :next_statement, :direct)
      def direct?
        direct
      end
    end
end
