require "test_helper"

class RuboCop::Callbacksystems::Autocorrection::CommentRescueTest < ActiveSupport::TestCase
  include SourceParsing, TextEditing

  test "preserving returns the original correction when no comment needs rescuing" do
    processed = processed_source("value = 1 # note\n")
    correction = edits_for(->(edits) { edits.replace("1", "2") })
    rehearsal = RuboCop::Callbacksystems::Autocorrection::Rehearsal.new(correction, processed)

    assert_same correction,
      RuboCop::Callbacksystems::Autocorrection::CommentRescue.new(rehearsal, processed).preserving(correction)
  end

  test "preserving returns nothing when the correction would relocate tooling" do
    source = "# :nocov:\nvalue = 1\n# :nocov:\n"
    processed = processed_source(source)
    correction = edits_for(->(edits) { edits.replace(source.chomp, "value = 2") })
    rehearsal = RuboCop::Callbacksystems::Autocorrection::Rehearsal.new(correction, processed)

    assert_nil RuboCop::Callbacksystems::Autocorrection::CommentRescue.new(rehearsal, processed).preserving(correction)
  end

  test "correction is nothing when no edit swallowed a comment" do
    assert_nil rescued("value = 1 # note\n") { it.replace("1", "2") }
  end

  test "correction keeps a comment trailing the first line on the rewritten first line" do
    source = "return unless ready? # why\nrun\n"

    assert_equal "if ready? # why\n  run\nend\n", rescued(source) { it.replace(source.chomp, "if ready?\n  run\nend") }
  end

  test "correction moves a comment trailing a later line to the rewritten last line" do
    source = "users\n  .where(active: true) # active ones\n"

    assert_equal "users.where(active: true) # active ones\n", rescued(source) { |edits|
      edits.replace(source.chomp, "users.where(active: true)")
    }
  end

  test "correction stands a comment of its own below the rewritten span" do
    source = "a = 1\n# between\nb = 2\n"

    assert_equal "b = 2\na = 1\n# between\n", rescued(source) { it.replace(source.chomp, "b = 2\na = 1") }
  end

  test "correction keeps the comment of a rewritten line trailing the new one" do
    source = "def total\n  # about\n  value = 1 # the value\n  value\nend\n"

    assert_equal "def total\n  # about\n  1 # the value\nend\n", rescued(source) { |edits|
      edits.replace("value = 1 # the value\n  value", "1")
      edits.remove("# about\n  ")
    }
  end

  test "correction keeps the comment of a removed line trailing the code before it" do
    source = "def total\n  run # first\n  nil\nend\n"

    assert_equal "def total\n  run # first\nend\n", rescued(source) { it.remove(" # first\n  nil") }
  end

  test "correction keeps a removed line's comment above the code that follows" do
    source = "def total\n  value = 1 # first\n  run(value)\nend\n"

    assert_equal "def total\n  # first\n  run(1)\nend\n", rescued(source) { |edits|
      edits.remove("value = 1 # first\n  ")
      edits.replace("run(value)", "run(1)")
    }
  end

  test "correction stands the comment of a removed top-level line above the code that follows" do
    assert_equal "# note\nb = 2\n", rescued("a = 1 # note\nb = 2\n") { it.remove("a = 1 # note\n") }
  end

  test "correction stands every comment of a removed span on lines of their own" do
    source = "a = 1 # one\nb = 2 # two\nc = 3\n"

    assert_equal "# one\n# two\nc = 3\n", rescued(source) { it.remove("a = 1 # one\nb = 2 # two\n") }
  end

  test "correction does not relocate a tooling directive" do
    source = "# :nocov:\nvalue = 1\n# :nocov:\n"

    assert_nil rescued(source) { it.replace(source.chomp, "value = 2") }
  end

  test "correction keeps the newline closing the replacement text" do
    assert_equal "b # note\nb = 2\n", rescued("a = 1 # note\nb = 2\n") { it.replace("a = 1 # note\n", "b\n") }
  end

  private
    def rescued(source, &correction)
      processed = processed_source(source)
      rehearsal = RuboCop::Callbacksystems::Autocorrection::Rehearsal.new(edits_for(correction), processed)
      rescue_correction = RuboCop::Callbacksystems::Autocorrection::CommentRescue.new(rehearsal, processed).correction
      rescue_correction && RuboCop::Cop::Corrector.new(processed).tap { rescue_correction.call(it) }.rewrite
    end
end
