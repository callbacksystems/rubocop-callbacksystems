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
class RuboCop::Cop::Callbacksystems::RepeatedFixtureInTests < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers

  MESSAGE = "Fixture `%<fixture>s` is used in multiple tests. Move it to `setup`."

  def on_new_investigation
    each_offense { |node, message| add_offense(node, message: message) }
  end

  private
    def each_offense(&block)
      if block
        repeated_fixture_calls.each do |signature, calls|
          calls.drop(1).each { yield it, format(MESSAGE, fixture: signature) }
        end
      else
        to_enum(__method__)
      end
    end

    def repeated_fixture_calls
      fixture_usages.select { |_, calls| calls.many? }
    end

    def fixture_usages
      if processed_source.ast
        test_blocks
          .flat_map { fixture_calls_in(it) }
          .group_by(&:signature)
          .transform_values { it.map(&:node) }
      else
        {}
      end
    end

    def fixture_calls_in(test_block)
      test_block.each_node(:send).filter_map do |node|
        fixture = RuboCop::Callbacksystems::FixtureCall.new(node)
        fixture if fixture.valid?
      end
    end
end
