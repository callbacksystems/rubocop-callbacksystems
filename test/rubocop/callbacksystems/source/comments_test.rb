require "test_helper"

class RuboCop::Callbacksystems::Source::CommentsTest < ActiveSupport::TestCase
  include SourceParsing

  test "for shares the position index for one processed source" do
    source = processed_source("# note\ndef run; end\n")

    assert_same RuboCop::Callbacksystems::Source::Comments.for(source), RuboCop::Callbacksystems::Source::Comments.for(source)
  end

  test "any_within? finds a comment inside a node" do
    source = processed_source("items = [\n  1 # note\n]\n")

    assert comments_in(source).any_within?(source.ast)
  end

  test "any_within? ignores comments before and after a node" do
    source = processed_source("# before\nitems = [ 1 ]\n# after\n")

    assert_not comments_in(source).any_within?(source.ast)
  end

  test "tooling_within? finds a tooling directive inside a node" do
    source = processed_source("items = [\n  # rubocop:disable Metrics/MethodLength\n  1\n]\n")

    assert comments_in(source).tooling_within?(source.ast)
  end

  test "tooling_within? ignores prose inside and tooling outside a node" do
    source = processed_source("# rubocop:disable Metrics/MethodLength\nitems = [\n  # one item\n  1\n]\n")

    assert_not comments_in(source).tooling_within?(source.ast)
  end

  test "within returns only comments inside a node in source order" do
    source = processed_source("# before\nitems = [\n  # one\n  1 # two\n]\n# after\n")

    assert_equal [ "# one", "# two" ], comments_in(source).within(source.ast).map(&:text)
  end

  test "within is empty when every comment precedes the range" do
    source = processed_source("# before\nitems = [ 1 ]\n")

    assert_empty comments_in(source).within(source.ast)
  end

  test "within excludes a comment that only partly overlaps the range" do
    source = processed_source("items = [\n  # note\n  1\n]\n")
    comment = source.comments.first
    partial_range = source.ast.source_range.with(end_pos: comment.source_range.begin_pos)

    assert_empty comments_in(source).within(partial_range)
  end

  test "within can be enumerated lazily" do
    source = processed_source("items = [\n  # note\n  1\n]\n")

    assert_equal [ "# note" ], RuboCop::Callbacksystems::Source::Comments::CommentsWithin
      .new(source.comments, source.ast.source_range, from: 0).each.map(&:text)
  end

  test "within can be enumerated more than once" do
    source = processed_source("items = [\n  # note\n  1\n]\n")
    comments = RuboCop::Callbacksystems::Source::Comments::CommentsWithin
      .new(source.comments, source.ast.source_range, from: 0)

    2.times { assert_equal [ "# note" ], comments.map(&:text) }
  end

  test "own_line_comment_on returns the comment occupying its own line" do
    source = processed_source("# own\ndef run; end # trailing\n")

    assert_equal "# own", comments_in(source).own_line_comment_on(1).text
    assert_nil comments_in(source).own_line_comment_on(2)
  end

  test "trailing_comment_on returns the comment following code" do
    source = processed_source("# own\ndef run; end # trailing\n")

    assert_equal "# trailing", comments_in(source).trailing_comment_on(2).text
    assert_nil comments_in(source).trailing_comment_on(1)
  end

  test "any_on_lines? tells whether the inclusive line range carries comments" do
    source = processed_source("# before\nitems = [ 1 ]\n# after\n")
    comments = comments_in(source)

    assert comments.any_on_lines?(1..1)
    assert_not comments.any_on_lines?(2..2)
    assert_not comments.any_on_lines?(3..2)
  end

  test "on_lines returns comments on the inclusive line range" do
    source = processed_source("# before\nitems = [ # first\n  1 # second\n]\n# after\n")
    comments = comments_in(source).on_lines(2..4)

    assert_equal [ "# first", "# second" ], comments.map(&:text)
    assert_empty comments_in(source).on_lines(4..3)
  end

  test "comments on lines return an enumerator without a block" do
    source = processed_source("# first\nvalue = 1 # second\n")
    comments = RuboCop::Callbacksystems::Source::Comments::CommentsOnLines.new(source.comments, 1..2, from: 0)

    assert_instance_of Enumerator, comments.each
    assert_equal [ "# first", "# second" ], comments.each.map(&:text)
  end

  private
    def comments_in(source)
      RuboCop::Callbacksystems::Source::Comments.new(source.comments)
    end
end
