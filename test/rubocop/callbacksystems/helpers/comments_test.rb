require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::CommentsTest < HelpersTestCase
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
    def comment_in(source)
      processed_source(source).comments.first
    end
end
