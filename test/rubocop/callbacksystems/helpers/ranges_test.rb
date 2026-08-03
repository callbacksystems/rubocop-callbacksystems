require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::RangesTest < HelpersTestCase
  test "statement_removal_range_for swallows the blank line above the node" do
    source = "foo\n\n  bar = 1\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.last
    range = Helpers.statement_removal_range_for(node)

    assert_equal "\n  bar = 1\n", range.source
  end

  test "statement_removal_range_for swallows the blank line below when the line above holds code" do
    source = "foo\n  bar = 1\n\nbaz\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.second
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n\n", range.source
  end

  test "statement_removal_range_for keeps both neighbours when they hold code" do
    source = "foo\n  bar = 1\nbaz\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.second
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n", range.source
  end

  test "statement_removal_range_for handles a node on the first line" do
    source = "  bar = 1\nfoo\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.first
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n", range.source
  end

  test "line_removal_range_for covers the full line and its trailing newline" do
    source = "  foo = 1\nbar\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.first
    range = Helpers.line_removal_range_for(node)

    assert_equal "  foo = 1\n", range.source
  end

  test "line_removal_range_for stops at end of source when no trailing newline" do
    source = "  foo = 1"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    range = Helpers.line_removal_range_for(processed.ast)

    assert_equal "  foo = 1", range.source
  end

  test "indentation_of returns the spaces the node starts at" do
    processed = RuboCop::AST::ProcessedSource.new("    foo = 1", RUBY_VERSION.to_f)

    assert_equal "    ", Helpers.indentation_of(processed.ast)
  end

  test "indentation_of returns an empty string for a node at the margin" do
    processed = RuboCop::AST::ProcessedSource.new("foo = 1", RUBY_VERSION.to_f)

    assert_equal "", Helpers.indentation_of(processed.ast)
  end

  test "source_end_of reaches past the body of a heredoc the node holds" do
    node = processed_source(<<~RUBY).ast
      wrap(<<~TEXT)
        hello
      TEXT
    RUBY

    assert_equal "wrap(<<~TEXT)\n  hello\nTEXT", node.source_range.with(end_pos: Helpers.source_end_of(node)).source
  end

  test "source_end_of is the node's own end when it holds no heredoc" do
    node = processed_source("wrap(body)\n").ast

    assert_equal node.source_range.end_pos, Helpers.source_end_of(node)
  end
end
