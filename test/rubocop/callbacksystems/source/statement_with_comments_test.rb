require "test_helper"

class RuboCop::Callbacksystems::Source::StatementWithCommentsTest < ActiveSupport::TestCase
  include SourceParsing

  test "sibling_lines_for shares the position index for one processed source" do
    processed = processed_source("def first; end; def second; end\n")

    first = RuboCop::Callbacksystems::Source::StatementWithComments.sibling_lines_for(processed)
    second = RuboCop::Callbacksystems::Source::StatementWithComments.sibling_lines_for(processed)

    assert_same first, second
  end

  test "contains_tooling_comment? finds a directive anywhere inside the statement" do
    processed = processed_source(<<~RUBY)
      def bar
        # rubocop:disable Metrics/MethodLength
        work
      end
    RUBY

    block = RuboCop::Callbacksystems::Source::StatementWithComments.new(processed.ast, processed)

    assert block.contains_tooling_comment?
  end

  test "contains_tooling_comment? ignores prose" do
    processed = processed_source("# What this does.\ndef bar; end\n")
    block = RuboCop::Callbacksystems::Source::StatementWithComments.new(processed.ast, processed)

    assert_not block.contains_tooling_comment?
  end

  test "range covers the statement alone when nothing sits above it" do
    assert_equal "def bar; end", block_source_of(<<~RUBY)
      def bar; end
    RUBY
  end

  test "range reaches up over the own-line comments written directly above" do
    assert_equal "# what it does\n# and why\ndef bar; end", block_source_of(<<~RUBY)
      # what it does
      # and why
      def bar; end
    RUBY
  end

  test "range reaches over a long comment run without recursive traversal" do
    comments = 2_000.times.map { "# comment #{it}" }.join("\n")

    assert_equal "# comment 0", block_source_of("#{comments}\ndef bar; end\n").lines.first.chomp
  end

  test "range stops at a blank line between the comment and the statement" do
    assert_equal "def bar; end", block_source_of(<<~RUBY)
      # unrelated

      def bar; end
    RUBY
  end

  test "range leaves out a trailing comment on the line above" do
    assert_equal "def bar; end", block_source_of(<<~RUBY)
      value = 1 # trailing
      def bar; end
    RUBY
  end

  test "range reaches over the comment trailing the statement's last line" do
    assert_equal "def bar; end # why", block_source_of(<<~RUBY)
      def bar; end # why
    RUBY
  end

  test "range reaches over the comment trailing a block's closing line" do
    assert_equal "# above\ndef bar\n  1\nend # why", block_source_of(<<~RUBY)
      # above
      def bar
        1
      end # why
    RUBY
  end

  test "range stops at the last line of a statement whose next line is commented" do
    assert_equal "def bar; end", block_source_of(<<~RUBY)
      def bar; end
      value = 1 # trailing
    RUBY
  end

  test "range excludes the separator and following statements for the first statement on a shared line" do
    assert_equal "def bar; end", block_source_of("def bar; end; def baz; end # baz\n", method_name: :bar)
  end

  test "range excludes both separators for a statement in the middle of a shared line" do
    source = "def foo; end; def bar; end; def baz; end # baz\n"

    assert_equal "def bar; end", block_source_of(source, method_name: :bar)
  end

  test "range gives the last statement the comment trailing its shared line" do
    assert_equal "def baz; end # baz", block_source_of("def bar; end; def baz; end # baz\n", method_name: :baz)
  end

  test "begin_position points at the first column of the block" do
    processed = processed_source(<<~RUBY)
      class Foo
        # what it does
        def bar; end
      end
    RUBY

    block = RuboCop::Callbacksystems::Source::StatementWithComments.new(processed.ast.body, processed)

    assert_equal processed.buffer.source.index("  # what it does"), block.begin_position
  end

  private
    def block_source_of(source, method_name: :bar)
      processed = processed_source(source)
      statement = processed.ast.each_node(:def).find { it.method?(method_name) }

      RuboCop::Callbacksystems::Source::StatementWithComments.new(statement, processed).range.source
    end
end
