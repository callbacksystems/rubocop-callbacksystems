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
class RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Fixture `%<fixture>s(:%<argument>s)` is assigned to `%<variable>s` but only used once. Inline it instead."

  # @!method fixture_assignment(node)
  def_node_matcher :fixture_assignment, <<~PATTERN
    (lvasgn $_variable_name $send)
  PATTERN

  # @!method variable_references(node)
  def_node_search :variable_references, <<~PATTERN
    (lvar %1)
  PATTERN

  def on_block(node)
    return unless test_block?(node)

    each_single_use_fixture(node.body) do |assignment, variable_name, fixture_call, usage_node|
      add_offense(assignment, message: format(MESSAGE, fixture: fixture_call.method_name, argument: fixture_call.first_argument.value, variable: variable_name)) do |corrector|
        corrector.remove(line_removal_range(assignment))
        corrector.replace(usage_node, fixture_call.source)
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def each_single_use_fixture(body)
      return unless body

      body.each_node(:lvasgn) do |assignment|
        next unless (variable_name, fixture_call = fixture_assignment(assignment)) && RuboCop::Callbacksystems::FixtureCall.new(fixture_call).valid?

        usage_node = single_use_node(body, variable_name, assignment)
        yield assignment, variable_name, fixture_call, usage_node if usage_node
      end
    end

    def single_use_node(body, variable_name, assignment)
      references = variable_references(body, variable_name).reject { it.equal?(assignment.children.last) }
      references.first if effective_count(body, references, variable_name) == 1
    end

    def effective_count(body, references, variable_name)
      any_in_iterator?(body, variable_name) ? 2 : references.size
    end

    def any_in_iterator?(body, variable_name)
      body.each_node(*BLOCK_NODE_TYPES).any? do |iterator|
        variable_references(iterator.body, variable_name).any?
      end
    end
end
