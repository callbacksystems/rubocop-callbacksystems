# Detects a fixture called in several tests of one file. Each test then repeats
# the line naming the record, and a reader learns which record the file is
# about only by comparing them, where one `setup` says it once and every test
# reads it from there.
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
  include RuboCop::Callbacksystems::Testing::CopHelpers

  def external_dependency_checksum
    RuboCop::Callbacksystems::Source::FilesChecksum.for \
      "**/test/fixtures/**/*.yml", root: project_root, include_contents: false
  end

  def on_new_investigation
    tests_by_class.each_value { report_each RepeatedFixtures.new(it, test_blocks:) }
  end

  private
    def tests_by_class
      test_blocks.each_with_object({}.compare_by_identity) do |test, groups|
        (groups[test_domain_of(test)] ||= []) << test
      end
    end

    def test_domain_of(test)
      RuboCop::Callbacksystems::Methods::Domain.new(test).container || processed_source.ast
    end

    class RepeatedFixtures
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Fixture `%<fixture>s` is used in multiple tests. Move it to `setup`."

      def initialize(tests, test_blocks:)
        @tests = tests
        @test_block_index = {}.compare_by_identity
        test_blocks.each { @test_block_index[it] = true }
      end

      def each_offense
        repeated_calls.each { yield RuboCop::Callbacksystems::Offense.new(it.node, message_for(it)) }
      end

      private
        attr_reader :tests, :test_block_index

        def repeated_calls
          calls.group_by(&:identity).values.select { spans_several_tests?(it) }.flat_map { beyond_first_test(it) }
        end

        def calls
          tests.flat_map { calls_in(it) }
        end

        def calls_in(test)
          RuboCop::Callbacksystems::Execution::Immediate.new(test.body, deferred_blocks: nested_tests_in(test))
            .nodes_of_type(:send)
            .map { RuboCop::Callbacksystems::Testing::FixtureCall.new(it) }.select(&:valid?).map { Call.new(test, it) }
        end

        def nested_tests_in(test)
          nodes_in(test.body, :any_block).select { test_block_index.key?(it) }
        end

        def spans_several_tests?(calls)
          calls.map(&:test).uniq(&:object_id).many?
        end

        def beyond_first_test(calls)
          calls.reject { it.test.equal?(calls.first.test) }
        end

        def message_for(call)
          format(MESSAGE, fixture: call.signature)
        end

        class Call < Data.define(:test, :fixture)
          delegate :identity, :node, :signature, to: :fixture
        end
    end
end
