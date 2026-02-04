# Detects when the same fixture is called in multiple tests.
# If a fixture is used in multiple tests, it should be moved to setup.
#
# @example
#   # bad - same fixture in multiple tests
#   test "validates name" do
#     user = users(:john)
#     assert user.valid?
#   end
#
#   test "validates email" do
#     user = users(:john)
#     assert user.email.present?
#   end
#
#   # good - fixture in setup
#   setup do
#     @user = users(:john)
#   end
#
#   test "validates name" do
#     assert @user.valid?
#   end
#
#   test "validates email" do
#     assert @user.email.present?
#   end
#
class RuboCop::Cop::Callbacksystems::RepeatedFixtureInTests < RuboCop::Cop::Base
  # Matches: test "description" do ... end
  def_node_matcher :test_block?, <<~PATTERN
    (block (send nil? :test (str _)) ...)
  PATTERN

  def on_new_investigation
    return unless processed_source.ast

    fixture_usages.each do |fixture_key, calls|
      next unless calls.many?

      calls.drop(1).each do |call|
        add_offense(call, message: "Fixture `#{fixture_key}` is used in multiple tests. Move it to `setup`.")
      end
    end
  end

  private
    def fixture_usages
      test_blocks.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |test_block, usages|
        collect_fixture_calls(test_block).each { |fixture_call| usages[fixture_call.signature] << fixture_call.node }
      end
    end

    def test_blocks
      processed_source.ast.each_node(:block).select { |n| test_block?(n) }
    end

    def collect_fixture_calls(test_block)
      test_block.each_node(:send).filter_map do |node|
        fixture = RuboCop::Callbacksystems::FixtureCall.new(node)
        fixture if fixture.valid?
      end
    end
end
