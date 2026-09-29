require "test_helper"

class RuboCop::Callbacksystems::Autocorrection::RehearsalTest < ActiveSupport::TestCase
  include SourceParsing, TextEditing

  test "empty? is true for a correction that touches nothing" do
    assert_predicate rehearsal("value = 1 # note\n") { nil }, :empty?
  end

  test "as_replacements lists the edits the correction made" do
    replacements = rehearsal("value = 1\n") { it.replace("1", "2") }.as_replacements

    assert_equal [ "2" ], replacements.map(&:last)
  end

  test "parses? is true while the correction leaves valid syntax" do
    assert_predicate rehearsal("value = 1\n") { it.replace("1", "2") }, :parses?
  end

  test "parses? is false once the correction breaks the syntax" do
    assert_not_predicate rehearsal("value = 1\n") { it.replace("1", "(") }, :parses?
  end

  test "parses? honors a target Ruby version handled by the legacy parser" do
    assert_predicate rehearsal("value = 1 # note\n", ruby_version: 2.7) { it.replace("1", "2") }, :parses?
  end

  test "keeps_comments? is true while every comment survives" do
    assert_predicate rehearsal("value = 1 # note\n") { it.replace("1", "2") }, :keeps_comments?
  end

  test "keeps_comments? is false once a comment is gone" do
    assert_not_predicate rehearsal("value = 1 # note\n") { it.replace("1 # note", "2") }, :keeps_comments?
  end

  test "keeps_comments? counts a comment written twice" do
    source = "a = 1 # note\nb = 2 # note\n"

    assert_not_predicate rehearsal(source) { it.replace("2 # note", "3") }, :keeps_comments?
  end

  test "keeps_comments? does not mistake comment text inside a string for a comment" do
    source = "message = \"# note\"\nvalue = 1 # note\n"

    assert_not_predicate rehearsal(source) { it.replace("value = 1 # note", "value = 2") }, :keeps_comments?
  end

  test "keeps_comments? reads comments through the parser selected for an older target Ruby" do
    assert_predicate rehearsal("value = 1 # note\n", ruby_version: 2.7) { it.replace("1", "2") }, :keeps_comments?
  end

  private
    def rehearsal(source, ruby_version: RUBY_VERSION.to_f, &correction)
      processed = RuboCop::ProcessedSource.new(source, ruby_version)
      RuboCop::Callbacksystems::Autocorrection::Rehearsal.new(edits_for(correction), processed)
    end
end
