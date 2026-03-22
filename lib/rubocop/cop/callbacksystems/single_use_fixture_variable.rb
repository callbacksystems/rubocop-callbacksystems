# Detects when a fixture is assigned to a variable but only used once.
# In that case, inline the fixture call instead.
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
class RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::TestCopHelpers
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Fixture `%<fixture>s(:%<argument>s)` is assigned to `%<variable>s` but only used once. Inline it instead."
  ITERATOR_TYPES = %i[block numblock].freeze

  # Matches: variable = fixture_call, captures variable_name and fixture_call
  def_node_matcher :fixture_assignment, <<~PATTERN
    (lvasgn $_variable_name $send)
  PATTERN

  # Finds all local variable references
  def_node_search :variable_references, <<~PATTERN
    (lvar %1)
  PATTERN

  def on_block(node)
    return unless test_block?(node)

    each_single_use_fixture(node.body) do |assignment, variable_name, fixture_call, usage_node|
      add_offense(assignment, message: format(MESSAGE, fixture: fixture_call.method_name, argument: fixture_call.arguments.first.value, variable: variable_name)) do |corrector|
        corrector.remove(removal_range(assignment))
        corrector.replace(usage_node, fixture_call.source)
      end
    end
  end

  private
    def each_single_use_fixture(body)
      return unless body

      body.each_node(:lvasgn) do |assignment|
        variable_name, fixture_call = fixture_assignment(assignment)
        next unless variable_name && RuboCop::Callbacksystems::FixtureCall.new(fixture_call).valid?

        usage_node = single_use_node(body, variable_name, assignment)
        yield assignment, variable_name, fixture_call, usage_node if usage_node
      end
    end

    def single_use_node(body, variable_name, assignment)
      references = variable_references(body, variable_name).reject { |n| n.equal?(assignment.children.last) }
      references.first if effective_count(body, references, variable_name) == 1
    end

    def effective_count(body, references, variable_name)
      any_in_iterator?(body, variable_name) ? 2 : references.size
    end

    def any_in_iterator?(body, variable_name)
      body.each_node(*ITERATOR_TYPES).any? do |iterator|
        variable_references(iterator.body, variable_name).any?
      end
    end

    def removal_range(assignment)
      line_start = assignment.source_range.begin_pos - assignment.source_range.column
      line_end = assignment.source_range.source_buffer.source[assignment.source_range.end_pos] == "\n" ? assignment.source_range.end_pos + 1 : assignment.source_range.end_pos
      Parser::Source::Range.new(assignment.source_range.source_buffer, line_start, line_end)
    end
end
