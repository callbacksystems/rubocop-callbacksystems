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
