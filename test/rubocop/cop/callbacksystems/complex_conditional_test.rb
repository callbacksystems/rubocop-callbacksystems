require "test_helper"

class ComplexConditionalTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ComplexConditional

  test "registers offense for conditional with too many operators" do
    offenses = assert_offense <<~RUBY, count: 1
      if a && b && c
        do_something
      end
    RUBY

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
    assert_offense <<~RUBY, count: 1
      if a && b || c && d && e
        do_something
      end
    RUBY
  end

  test "works with unless" do
    assert_offense <<~RUBY, count: 1
      unless a && b && c && d && e
        do_something
      end
    RUBY
  end

  test "works with ternary" do
    assert_offense <<~RUBY, count: 1
      a && b && c && d && e ? foo : bar
    RUBY
  end

  test "works with modifier if" do
    assert_offense <<~RUBY, count: 1
      do_something if a && b && c && d && e
    RUBY
  end

  test "flags a complex while condition" do
    assert_offense <<~RUBY, count: 1
      while a && b && c
        work
      end
    RUBY
  end

  test "flags complex post-test loop conditions" do
    assert_offense <<~RUBY, count: 2
      begin
        work
      end while a && b && c

      begin
        work
      end until a && b && c
    RUBY
  end

  test "counts operators through parenthesized begin nodes" do
    assert_offense <<~RUBY, count: 1
      if ((a && b) && c)
        work
      end
    RUBY
  end

  test "counts operators through keyword begin nodes" do
    assert_offense <<~RUBY, count: 1
      if begin
           prepare
           a && b && c
         end
        work
      end
    RUBY
  end

  test "counts a boolean spine deeper than Ruby's call stack" do
    source = "if #{Array.new(2_000, "condition").join(" && ")}\n  work\nend\n"
    condition = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast.condition

    assert_equal 1_999, RuboCop::Cop::Callbacksystems::ComplexConditional::OperatorCount.new(condition).value
  end

  test "allows an empty keyword begin condition" do
    assert_no_offense <<~RUBY
      if begin
         end
        work
      end
    RUBY
  end

  test "counts only top-level operators, not those nested in arguments" do
    assert_no_offense <<~RUBY
      do_something if process(a || b) && c
    RUBY
  end
end
