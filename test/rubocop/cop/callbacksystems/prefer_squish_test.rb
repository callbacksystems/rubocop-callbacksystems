require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferSquishTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferSquish

  test "registers offense for strip.gsub with \\s+ pattern" do
    assert_offense <<~RUBY
      text.strip.gsub(/\\s+/, " ")
    RUBY
  end

  test "registers offense for strip.gsub with whitespace class pattern" do
    assert_offense <<~RUBY
      text.strip.gsub(/[[:space:]]+/, " ")
    RUBY
  end

  test "autocorrects to squish" do
    assert_correction 'text.strip.gsub(/\s+/, " ")', "text.squish"
  end

  test "autocorrects with method chain" do
    assert_correction 'name.downcase.strip.gsub(/\s+/, " ")', "name.downcase.squish"
  end

  test "autocorrects a receiverless call" do
    assert_correction 'strip.gsub(/\s+/, " ")', "squish"
  end

  test "autocorrects preserving safe navigation" do
    assert_correction 'text&.strip.gsub(/\s+/, " ")', "text&.squish"
  end

  test "autocorrects an outer safe navigation call" do
    assert_correction 'text&.strip&.gsub(/\s+/, " ")', "text&.squish"
  end

  test "does not offer correction when the replaced chain contains a comment" do
    assert_uncorrectable_offense <<~RUBY
      text.strip.gsub(
        /\\s+/, # Explain this normalization.
        " "
      )
    RUBY
  end

  test "does not offer correction when the replaced chain contains a tooling comment" do
    assert_uncorrectable_offense <<~RUBY
      text.strip.gsub(
        /\\s+/, # :nocov:
        " "
      )
    RUBY
  end

  test "leaves its correction at a fixed point" do
    assert_no_correction "text.squish"
  end

  test "does not register offense for gsub without strip" do
    assert_no_offense <<~RUBY
      text.gsub(/\\s+/, " ")
    RUBY
  end

  test "does not register offense for strip without gsub" do
    assert_no_offense <<~RUBY
      text.strip
    RUBY
  end

  test "does not register offense for different replacement" do
    assert_no_offense <<~RUBY
      text.strip.gsub(/\\s+/, "_")
    RUBY
  end

  test "does not register offense for different pattern" do
    assert_no_offense <<~RUBY
      text.strip.gsub(/\\d+/, " ")
    RUBY
  end
end
