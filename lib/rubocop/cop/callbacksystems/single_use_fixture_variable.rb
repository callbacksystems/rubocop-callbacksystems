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

  MESSAGE = "Fixture `%<fixture>s` is assigned to `%<variable>s` but only used once. Inline it instead."

  # @!method fixture_assignment(node)
  def_node_matcher :fixture_assignment, <<~PATTERN
    (lvasgn $_variable_name $send)
  PATTERN

  def on_block(node)
    if test_block?(node)
      each_single_use_fixture(node.body) do |assignment, variable_name, fixture, usage_node|
        add_offense(assignment, message: format(MESSAGE, fixture: fixture.signature, variable: variable_name)) do |corrector|
          corrector.remove(line_removal_range_for(assignment))
          corrector.replace(usage_node, fixture.node.source)
        end
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def each_single_use_fixture(body)
      body&.each_node(:lvasgn) do |assignment|
        next unless (variable_name, fixture = fixture_for(assignment))

        usage_node = Occurrences.new(body, variable_name).single_use_node_for(assignment)
        yield assignment, variable_name, fixture, usage_node if usage_node
      end
    end

    def fixture_for(assignment)
      variable_name, fixture_node = fixture_assignment(assignment)
      fixture = RuboCop::Callbacksystems::FixtureCall.new(fixture_node)
      [ variable_name, fixture ] if fixture.valid?
    end

    # Every reference to one variable within a test body.
    class Occurrences
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, variable_name)
        @body = body
        @variable_name = variable_name
      end

      def single_use_node_for(assignment)
        references = within(body).reject { it.equal?(assignment.expression) }
        references.first if references.one? && !in_iterator?
      end

      private
        attr_reader :body, :variable_name

        def within(scope)
          scope ? scope.each_node(:lvar).select { it.children.first == variable_name } : []
        end

        def in_iterator?
          body.each_node(*BLOCK_NODE_TYPES).any? { within(it.body).any? }
        end
    end
end
