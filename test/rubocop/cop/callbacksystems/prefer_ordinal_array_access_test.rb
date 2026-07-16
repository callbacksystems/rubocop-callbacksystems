require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccessTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccess

  test "registers offense for [1]" do
    assert_offense <<~RUBY
      items[1]
    RUBY
  end

  test "registers offense for [2]" do
    assert_offense <<~RUBY
      items[2]
    RUBY
  end

  test "registers offense for [3]" do
    assert_offense <<~RUBY
      items[3]
    RUBY
  end

  test "registers offense for [4]" do
    assert_offense <<~RUBY
      items[4]
    RUBY
  end

  test "registers offense for [-2]" do
    assert_offense <<~RUBY
      items[-2]
    RUBY
  end

  test "registers offense for [-3]" do
    assert_offense <<~RUBY
      items[-3]
    RUBY
  end

  test "autocorrects [1] to second" do
    assert_correction "items[1]", "items.second"
  end

  test "autocorrects [2] to third" do
    assert_correction "items[2]", "items.third"
  end

  test "autocorrects [-2] to second_to_last" do
    assert_correction "items[-2]", "items.second_to_last"
  end

  test "autocorrects with method chain" do
    assert_correction "users.active[1]", "users.active.second"
  end

  test "does not register offense for [0]" do
    assert_no_offense <<~RUBY
      items[0]
    RUBY
  end

  test "does not register offense for [5]" do
    assert_no_offense <<~RUBY
      items[5]
    RUBY
  end

  test "does not register offense for [-1]" do
    assert_no_offense <<~RUBY
      items[-1]
    RUBY
  end

  test "does not register offense for [-4]" do
    assert_no_offense <<~RUBY
      items[-4]
    RUBY
  end

  test "does not register offense for string index" do
    assert_no_offense <<~RUBY
      hash["key"]
    RUBY
  end

  test "does not register offense for symbol index" do
    assert_no_offense <<~RUBY
      hash[:key]
    RUBY
  end

  test "does not register offense for variable index" do
    assert_no_offense <<~RUBY
      items[index]
    RUBY
  end

  test "does not register offense for range index" do
    assert_no_offense <<~RUBY
      items[1..3]
    RUBY
  end

  test "does not register offense for a string receiver" do
    assert_no_offense <<~RUBY
      "value"[2]
    RUBY
  end

  test "does not register offense for an integer-keyed hash receiver" do
    assert_no_offense <<~RUBY
      { 2 => "value" }[2]
    RUBY
  end

  test "does not register offense for a MatchData receiver" do
    assert_no_offense <<~RUBY
      value.match(/pattern/)[2]
      Regexp.last_match[2]
    RUBY
  end
end
