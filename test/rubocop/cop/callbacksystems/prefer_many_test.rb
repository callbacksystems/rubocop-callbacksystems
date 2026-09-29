require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferManyTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferMany

  test "registers offense for size > 1" do
    assert_offense <<~RUBY
      users.size > 1
    RUBY
  end

  test "registers offense for length > 1" do
    assert_offense <<~RUBY
      users.length > 1
    RUBY
  end

  test "registers offense for count > 1" do
    assert_offense <<~RUBY
      users.count > 1
    RUBY
  end

  test "autocorrects size > 1 to many?" do
    assert_correction "users.size > 1", "users.many?"
  end

  test "autocorrects with method chain" do
    assert_correction "users.active.size > 1", "users.active.many?"
  end

  test "autocorrects a receiverless comparison" do
    assert_correction "size > 1", "many?"
  end

  test "autocorrects preserving safe navigation" do
    assert_correction "users&.size > 1", "users&.many?"
  end

  test "autocorrects a safely navigated comparison" do
    assert_correction "users&.size&.>(1)", "users&.many?"
  end

  test "does not offer correction when the comparison contains a comment" do
    assert_uncorrectable_offense <<~RUBY
      users.size > # Count actual users.
        1
    RUBY
  end

  test "does not offer correction when the comparison contains a tooling comment" do
    assert_uncorrectable_offense <<~RUBY
      users.size > # :nocov:
        1
    RUBY
  end

  test "leaves its correction at a fixed point" do
    assert_no_correction "users.many?"
  end

  test "does not register offense for size > 0" do
    assert_no_offense <<~RUBY
      users.size > 0
    RUBY
  end

  test "does not register offense for size > 2" do
    assert_no_offense <<~RUBY
      users.size > 2
    RUBY
  end

  test "does not register offense for size == 1" do
    assert_no_offense <<~RUBY
      users.size == 1
    RUBY
  end

  test "does not register offense for size < 1" do
    assert_no_offense <<~RUBY
      users.size < 1
    RUBY
  end

  test "does not register offense for 1 > size" do
    assert_no_offense <<~RUBY
      1 > users.size
    RUBY
  end

  test "allows a string literal, which has no many?" do
    assert_no_offense <<~RUBY
      "abc".size > 1
    RUBY
  end

  test "allows a receiver read as a string" do
    assert_no_offense <<~RUBY
      name.strip.length > 1
    RUBY
  end

  test "allows a joined receiver" do
    assert_no_offense <<~RUBY
      parts.join(", ").size > 1
    RUBY
  end

  test "registers offense for a receiver split into a collection" do
    assert_offense <<~RUBY
      text.lines.count > 1
    RUBY
  end
end
