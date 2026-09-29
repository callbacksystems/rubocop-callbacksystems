require "test_helper"

class RuboCop::Callbacksystems::Testing::CopHelpersTest < CopTestCase
  include SourceParsing

  test "included defines test_block? matcher on including class" do
    assert_respond_to TestCop.new, :test_block?
  end

  test "included defines setup_block? matcher on including class" do
    assert_respond_to TestCop.new, :setup_block?
  end

  test "test_block? recognizes explicit, numbered, and implicit it blocks" do
    blocks = [
      'test("one") { work }', 'test("two") { _1.work }', 'test("three") { it.work }'
    ].map { processed_source(it).ast }

    assert blocks.all? { TestCop.new.test_block?(it) }
  end

  test "test_block? recognizes an explicitly self-qualified test macro" do
    assert TestCop.new.test_block?(processed_source('self.test("one") { work }').ast)
  end

  test "setup_block? recognizes explicit, numbered, and implicit it blocks" do
    blocks = [ "setup { work }", "setup { _1.work }", "setup { it.work }" ].map { processed_source(it).ast }

    assert blocks.all? { TestCop.new.setup_block?(it) }
  end

  test "setup_block? recognizes an explicitly self-qualified setup macro" do
    assert TestCop.new.setup_block?(processed_source("self.setup { work }").ast)
  end

  test "test_blocks and setup_blocks collect every block representation" do
    source = processed_source(<<~RUBY).ast
      test("one") { work }
      test("two") { _1.work }
      test("three") { it.work }
      setup { work }
      setup { _1.work }
      setup { it.work }
    RUBY
    cop = TestCop.new

    assert_equal %i[ block numblock itblock ], cop.collected_test_blocks(source).map(&:type)
    assert_equal %i[ block numblock itblock ], cop.collected_setup_blocks(source).map(&:type)
  end

  test "immediate_calls_in caches calls that can run from one statement" do
    statement = processed_source("perform(validate); -> { deferred }; object&.save\n").ast
    cop = TestCop.new
    calls = cop.collected_immediate_calls_in(statement)

    assert_equal [ "perform(validate)", "validate", "object&.save", "object" ], calls.map(&:source)
    assert_same calls, cop.collected_immediate_calls_in(statement)
  end

  private
    class TestCop < RuboCop::Cop::Base
      include RuboCop::Callbacksystems::Helpers
      include RuboCop::Callbacksystems::Testing::CopHelpers

      def collected_test_blocks(source)
        test_blocks(source)
      end

      def collected_setup_blocks(source)
        setup_blocks(source)
      end

      def collected_immediate_calls_in(statement)
        immediate_calls_in(statement)
      end
    end
end
