require "test_helper"

class RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturn

  test "registers offense for each with return if" do
    assert_offense <<~RUBY
      items.each do |item|
        return item if item.valid?
      end
    RUBY
  end

  test "registers offense for each with return unless" do
    assert_offense <<~RUBY
      items.each do |item|
        return item unless item.invalid?
      end
    RUBY
  end

  test "registers offense in method context" do
    assert_offense <<~RUBY
      def find_valid
        items.each do |item|
          return item if item.valid?
        end
        nil
      end
    RUBY
  end

  test "allows find instead of each with return" do
    assert_no_offense <<~RUBY
      items.find { it.valid? }
    RUBY
  end

  test "allows each without return" do
    assert_no_offense <<~RUBY
      items.each do |item|
        process(item)
      end
    RUBY
  end

  test "allows each with unconditional return" do
    assert_no_offense <<~RUBY
      items.each do |item|
        process(item)
        return item
      end
    RUBY
  end

  test "allows detect instead of each" do
    assert_no_offense <<~RUBY
      items.detect { it.valid? }
    RUBY
  end
end
