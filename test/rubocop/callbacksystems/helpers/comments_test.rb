require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::CommentsTest < HelpersTestCase
  test "holds_comment? is true when the range covers a comment" do
    assert Helpers.holds_comment?(*whole_of("foo\n# a note\nbar\n"))
  end

  test "holds_comment? is false when the range covers no comment" do
    assert_not Helpers.holds_comment?(*whole_of("foo\nbar\n"))
  end

  test "first_comment_in returns the earliest comment the range covers" do
    assert_equal "# one", Helpers.first_comment_in(*whole_of("# one\nfoo\n# two\n")).text
  end

  test "range_ending_at_first_comment stops the range short of the comment" do
    range, comments = whole_of("foo\n# a note\nbar\n")

    assert_equal "foo\n", Helpers.range_ending_at_first_comment(range, comments).source
  end

  test "range_ending_at_first_comment returns the range untouched when it covers no comment" do
    range, comments = whole_of("foo\nbar\n")

    assert_equal range, Helpers.range_ending_at_first_comment(range, comments)
  end

  test "range_starting_after_last_comment starts the range past the comment" do
    range, comments = whole_of("foo\n# a note\nbar\n")

    assert_equal "\nbar\n", Helpers.range_starting_after_last_comment(range, comments).source
  end

  test "range_starting_after_last_comment returns the range untouched when it covers no comment" do
    range, comments = whole_of("foo\nbar\n")

    assert_equal range, Helpers.range_starting_after_last_comment(range, comments)
  end

  test "last_comment_in returns the latest comment the range covers" do
    assert_equal "# two", Helpers.last_comment_in(*whole_of("# one\nfoo\n# two\n")).text
  end

  test "comment_removal_range_for removes a full-line comment with its line" do
    range = Helpers.comment_removal_range_for(comment_in("  # a note\nbar\n"))

    assert_equal "  # a note\n", range.source
  end

  test "comment_removal_range_for strips a trailing comment and its leading space, keeping the code" do
    range = Helpers.comment_removal_range_for(comment_in("foo = 1 # a note\n"))

    assert_equal " # a note", range.source
  end

  test "own_line_comment? is true for a comment that occupies its whole line" do
    assert Helpers.own_line_comment?(comment_in("  # a note\n"))
  end

  test "own_line_comment? is false for a comment trailing code" do
    assert_not Helpers.own_line_comment?(comment_in("foo = 1 # a note\n"))
  end

  private
    def whole_of(source)
      parsed = processed_source(source)
      [ parsed.buffer.source_range, parsed.comments ]
    end

    def comment_in(source)
      processed_source(source).comments.first
    end
end
