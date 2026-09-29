require "test_helper"

class RuboCop::Callbacksystems::Helpers::RangesTest < HelpersTestCase
  test "statement_removal_range_for swallows the blank line above the node" do
    source = "foo\n\n  bar = 1\n"
    processed = processed_source(source)
    node = processed.ast.children.last
    range = Helpers.statement_removal_range_for(node)

    assert_equal "\n  bar = 1\n", range.source
  end

  test "statement_removal_range_for swallows the blank line below when the line above holds code" do
    source = "foo\n  bar = 1\n\nbaz\n"
    processed = processed_source(source)
    node = processed.ast.children.second
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n\n", range.source
  end

  test "statement_removal_range_for keeps both neighbors when they hold code" do
    source = "foo\n  bar = 1\nbaz\n"
    processed = processed_source(source)
    node = processed.ast.children.second
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n", range.source
  end

  test "statement_removal_range_for handles a node on the first line" do
    source = "  bar = 1\nfoo\n"
    processed = processed_source(source)
    node = processed.ast.children.first
    range = Helpers.statement_removal_range_for(node)

    assert_equal "  bar = 1\n", range.source
  end

  test "statement_removal_range_for takes the separator after the first of same-line statements" do
    processed = processed_source("remove; keep\n")

    assert_equal "remove; ", Helpers.statement_removal_range_for(processed.ast.children.first).source
  end

  test "statement_removal_range_for takes the following separator around a middle same-line statement" do
    processed = processed_source("keep; remove; retain # retained note\n")
    corrector = RuboCop::Cop::Corrector.new(processed)

    corrector.remove(Helpers.statement_removal_range_for(processed.ast.children.second))

    assert_equal "keep; retain # retained note\n", corrector.rewrite
  end

  test "statement_removal_range_for takes the separator before the last of same-line statements" do
    processed = processed_source("keep; remove\n")

    assert_equal "; remove", Helpers.statement_removal_range_for(processed.ast.children.last).source
  end

  test "statement_removal_range_for takes the separator between statements inside an explicit begin" do
    processed = processed_source("begin; remove; keep; end\n")

    assert_equal "remove; ", Helpers.statement_removal_range_for(processed.ast.children.first).source
  end

  test "statement_removal_range_of takes the blank line beside a span of lines" do
    source = "foo\n\n  bar = 1\n  baz = 2\nqux\n"
    processed = processed_source(source)
    span = Helpers.range_spanning(processed.ast.children[1..2])

    assert_equal "\n  bar = 1\n  baz = 2\n", Helpers.statement_removal_range_of(span).source
  end

  test "statement_removal_ranges_of joins statements separated by blank lines into one range" do
    source = "class Report\n  A = 1\n\n  B = 2\n\n  def total\n  end\nend\n"
    ranges = constant_ranges_in(source)

    joined = Helpers.statement_removal_ranges_of(ranges)

    assert_equal 1, joined.size
    assert_equal "  A = 1\n\n  B = 2\n\n", joined.first.source
  end

  test "statement_removal_ranges_of keeps statements with code between them apart" do
    source = "class Report\n  A = 1\n  def total\n  end\n  B = 2\nend\n"
    ranges = constant_ranges_in(source)

    assert_equal 2, Helpers.statement_removal_ranges_of(ranges).size
  end

  test "statement_removal_ranges_of returns nothing for no ranges" do
    assert_empty Helpers.statement_removal_ranges_of([])
  end

  test "span_of covers from the first range to the last" do
    processed = processed_source("foo = 1\nbar = 2\nbaz = 3\n")
    ranges = processed.ast.children.map(&:source_range)

    assert_equal "foo = 1\nbar = 2\nbaz = 3", Helpers.span_of(ranges).source
  end

  test "span_of covers just the range when given a single one" do
    processed = processed_source("foo = 1\n")

    assert_equal "foo = 1", Helpers.span_of([ processed.ast.source_range ]).source
  end

  test "line_removal_range_for covers the full line and its trailing newline" do
    source = "  foo = 1\nbar\n"
    processed = processed_source(source)
    node = processed.ast.children.first
    range = Helpers.line_removal_range_for(node)

    assert_equal "  foo = 1\n", range.source
  end

  test "line_removal_range_for stops at end of source when no trailing newline" do
    source = "  foo = 1"
    processed = processed_source(source)
    range = Helpers.line_removal_range_for(processed.ast)

    assert_equal "  foo = 1", range.source
  end

  test "line_removal_range_of takes the whole lines of a range and the newline closing them" do
    processed = processed_source("foo\n  bar(\n    1\n  )\nbaz\n")
    call = processed.ast.children.second

    assert_equal "  bar(\n    1\n  )\n", Helpers.line_removal_range_of(call.loc.begin.join(call.loc.end)).source
  end

  test "indentation_of returns the spaces the node starts at" do
    processed = processed_source("    foo = 1")

    assert_equal "    ", Helpers.indentation_of(processed.ast)
  end

  test "indentation_of returns an empty string for a node at the margin" do
    processed = processed_source("foo = 1")

    assert_equal "", Helpers.indentation_of(processed.ast)
  end

  test "call_prefix_of keeps the receiver and its safe navigation operator" do
    processed = processed_source("users.active&.preload(:posts)")

    assert_equal "users.active&.", Helpers.call_prefix_of(processed.ast)
  end

  test "call_prefix_of keeps whitespace and comments before the selector" do
    processed = processed_source("users. # association loading\n  preload(:posts)")

    assert_equal "users. # association loading\n  ", Helpers.call_prefix_of(processed.ast)
  end

  test "call_prefix_of is empty for a receiverless call" do
    processed = processed_source("preload(:posts)")

    assert_empty Helpers.call_prefix_of(processed.ast)
  end

  test "carries_heredoc? is true for a node whose string keeps its body on later lines" do
    processed = processed_source("execute <<-SQL\n  SELECT 1\nSQL\n")

    assert Helpers.carries_heredoc?(processed.ast)
  end

  test "carries_heredoc? is false for a node whose strings sit on one line" do
    processed = processed_source(%(execute("SELECT 1")\n))

    assert_not Helpers.carries_heredoc?(processed.ast)
  end

  test "range_through_heredocs reaches past the body a heredoc keeps on later lines" do
    source = "execute <<-SQL\n  SELECT 1\nSQL\n"
    processed = processed_source(source)

    assert_equal source.rstrip, Helpers.range_through_heredocs(processed.ast).source
  end

  test "range_through_heredocs leaves a node without heredocs where it ends" do
    processed = processed_source("foo(bar)\n")

    assert_equal "foo(bar)", Helpers.range_through_heredocs(processed.ast).source
  end

  test "range_spanning covers from the first node to the last" do
    processed = processed_source("foo = 1\nbar = 2\nbaz = 3\n")
    nodes = processed.ast.children

    assert_equal "foo = 1\nbar = 2\nbaz = 3", Helpers.range_spanning(nodes).source
  end

  test "range_spanning covers just the node when given a single one" do
    processed = processed_source("foo = 1\n")

    assert_equal "foo = 1", Helpers.range_spanning([ processed.ast ]).source
  end

  test "fits_on_line? is true when the source, its indentation and what trails the node fit the limit" do
    processed = processed_source("  foo(bar).baz\n")
    inner = processed.ast.each_node(:send).find { it.method?(:foo) }

    assert Helpers.fits_on_line?(inner, "foo(bar)", 14)
    assert_not Helpers.fits_on_line?(inner, "foo(bar)", 13)
  end

  test "trailing_length_of counts what is left on the line after the node" do
    processed = processed_source("foo(bar).baz\n")
    inner = processed.ast.each_node(:send).find { it.method?(:foo) }

    assert_equal ".baz".length, Helpers.trailing_length_of(inner)
  end

  test "trailing_length_of counts nothing when the node ends its line" do
    processed = processed_source("foo(bar)\n")

    assert_equal 0, Helpers.trailing_length_of(processed.ast)
  end

  test "line_start_position_of skips back over the indentation to the start of the line" do
    source = "foo\n    bar = 1\n"
    processed = processed_source(source)
    node = processed.ast.children.last

    assert_equal source.index("    bar"), Helpers.line_start_position_of(node)
  end

  test "line_start_position_of returns the node position for a node at the margin" do
    processed = processed_source("foo = 1")

    assert_equal 0, Helpers.line_start_position_of(processed.ast)
  end

  private
    def constant_ranges_in(source)
      processed_source(source).ast.each_node(:casgn).map(&:source_range)
    end
end
