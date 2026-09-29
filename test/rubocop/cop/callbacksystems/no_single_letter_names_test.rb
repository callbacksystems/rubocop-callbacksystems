require "test_helper"

class RuboCop::Cop::Callbacksystems::NoSingleLetterNamesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoSingleLetterNames

  test "registers offense for single-letter local variable" do
    assert_offense <<~RUBY
      x = 5
    RUBY
  end

  test "registers offense for single-letter block argument" do
    assert_offense <<~RUBY
      items.each { |i| process(i) }
    RUBY
  end

  test "registers offense for single-letter method parameter" do
    assert_offense <<~RUBY
      def foo(n)
        n + 1
      end
    RUBY
  end

  test "registers offense for single-letter map block argument" do
    assert_offense <<~RUBY
      items.map { |e| e.name }
    RUBY
  end

  test "registers offense for multiple single-letter block arguments" do
    assert_offense <<~RUBY, count: 2
      hash.each { |k, v| puts k }
    RUBY
  end

  test "registers offense for single-letter optional parameter" do
    assert_offense <<~RUBY
      def foo(n = 5)
        n + 1
      end
    RUBY
  end

  test "registers offense for single-letter keyword parameter" do
    assert_offense <<~RUBY
      def foo(n:)
        n + 1
      end
    RUBY
  end

  test "registers offense for single-letter keyword optional parameter" do
    assert_offense <<~RUBY
      def foo(n: 5)
        n + 1
      end
    RUBY
  end

  test "registers offense for single-letter pattern variable" do
    assert_offense <<~RUBY
      case payload
      in { name: n }
      end
    RUBY
  end

  test "registers offense for single-letter shadow argument" do
    assert_offense <<~RUBY
      records.each { |;x| consume(x) }
    RUBY
  end

  test "allows descriptive local variable names" do
    assert_no_offense <<~RUBY
      count = 5
    RUBY
  end

  test "allows descriptive block argument names" do
    assert_no_offense <<~RUBY
      items.each { |item| process(item) }
    RUBY
  end

  test "allows descriptive method parameter names" do
    assert_no_offense <<~RUBY
      def foo(number)
        number + 1
      end
    RUBY
  end

  test "allows descriptive hash block argument names" do
    assert_no_offense <<~RUBY
      hash.each { |key, value| puts key }
    RUBY
  end

  test "allows underscore for unused block argument" do
    assert_no_offense <<~RUBY
      items.each { |_| process }
    RUBY
  end

  test "allows underscore-prefixed names for unused arguments" do
    assert_no_offense <<~RUBY
      [1, 2].each_with_index { |_element, index| puts index }
    RUBY
  end

  test "allows anonymous rest, keyword rest, and block arguments" do
    assert_no_offense <<~RUBY
      def foo(*, **, &)
      end
    RUBY
  end
end
