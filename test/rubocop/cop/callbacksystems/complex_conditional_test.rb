require "test_helper"

class ComplexConditionalTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ComplexConditional

  test "registers offense for conditional with too many operators" do
    offenses = assert_offense <<~RUBY
      if a && b && c
        do_something
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "2 boolean operators"
  end

  test "no offense for conditional with single operator" do
    assert_no_offense <<~RUBY
      if a && b
        do_something
      end
    RUBY
  end

  test "no offense for simple conditional" do
    assert_no_offense <<~RUBY
      if a
        do_something
      end
    RUBY
  end

  test "counts both && and ||" do
    offenses = assert_offense <<~RUBY
      if a && b || c && d && e
        do_something
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "works with unless" do
    offenses = assert_offense <<~RUBY
      unless a && b && c && d && e
        do_something
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "works with ternary" do
    offenses = assert_offense <<~RUBY
      a && b && c && d && e ? foo : bar
    RUBY

    assert_equal 1, offenses.count
  end

  test "works with modifier if" do
    offenses = assert_offense <<~RUBY
      do_something if a && b && c && d && e
    RUBY

    assert_equal 1, offenses.count
  end

  test "flags a complex while condition" do
    offenses = assert_offense <<~RUBY
      while a && b && c
        work
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "counts only top-level operators, not those nested in arguments" do
    assert_no_offense <<~RUBY
      do_something if process(a || b) && c
    RUBY
  end
end
