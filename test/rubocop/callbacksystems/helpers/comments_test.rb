require "test_helper"

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

  test "comment_blocks_in groups the consecutive own-line comments of the source" do
    blocks = Helpers.comment_blocks_in(processed_source("# one\n# two\nfoo # three\n"))

    assert_equal [ [ "# one", "# two" ] ], blocks.map { it.map(&:text) }
  end

  test "prose_comments_in leaves out the comments addressing the tooling" do
    comments = Helpers.prose_comments_in(processed_source("# frozen_string_literal: true\n# a note\nfoo\n"))

    assert_equal [ "# a note" ], comments.map(&:text)
  end

  test "tooling_comment? is true for a shebang" do
    assert Helpers.tooling_comment?(comment_in("#!/usr/bin/env ruby\n"))
  end

  test "tooling_comment? is true for a magic comment" do
    assert Helpers.tooling_comment?(comment_in("# frozen_string_literal: true\n"))
  end

  test "tooling_comment? is true for a directive, including one written without a cop name" do
    assert Helpers.tooling_comment?(comment_in("# rubocop:disable Metrics/AbcSize\n"))
    assert Helpers.tooling_comment?(comment_in("# rubocop:enable\n"))
  end

  test "tooling_comment? is true for directives that hide and resume RDoc output" do
    assert Helpers.tooling_comment?(comment_in("#--\n"))
    assert Helpers.tooling_comment?(comment_in("#++\n"))
  end

  test "tooling_comment? is true for namespaced directives from other tools" do
    assert Helpers.tooling_comment?(comment_in("# steep:ignore:start\n"))
    assert Helpers.tooling_comment?(comment_in("# standard:disable Style/StringLiterals\n"))
    assert Helpers.tooling_comment?(comment_in("# :reek:DuplicateMethodCall\n"))
    assert Helpers.tooling_comment?(comment_in("# typed: strict\n"))
    assert Helpers.tooling_comment?(comment_in("# rbs_inline: enabled\n"))
  end

  test "tooling_comment? is true for inline type annotations" do
    assert Helpers.tooling_comment?(comment_in("# @rbs (String) -> Symbol\n"))
    assert Helpers.tooling_comment?(comment_in("# @type var name: String\n"))
    assert Helpers.tooling_comment?(comment_in("# @implements _Each[String]\n"))
    assert Helpers.tooling_comment?(comment_in("# @dynamic find_by_name\n"))
  end

  test "tooling_comment? is true for colon-delimited RDoc directives" do
    assert Helpers.tooling_comment?(comment_in("# :call-seq:\n"))
    assert Helpers.tooling_comment?(comment_in("# :yields: value\n"))
  end

  test "tooling_comment? is true for coverage and formatter sentinels" do
    assert Helpers.tooling_comment?(comment_in("# :nocov:\n"))
    assert Helpers.tooling_comment?(comment_in("# nocov\n"))
    assert Helpers.tooling_comment?(comment_in("# stree-ignore\n"))
  end

  test "tooling_comment? is false for a comment addressing the reader" do
    assert_not Helpers.tooling_comment?(comment_in("# a note\n"))
    assert_not Helpers.tooling_comment?(comment_in("# Note: this still addresses the reader\n"))
  end

  private
    def comment_in(source)
      processed_source(source).comments.first
    end
end
