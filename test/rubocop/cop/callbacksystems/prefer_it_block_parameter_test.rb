require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferItBlockParameterTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferItBlockParameter

  test "registers offense for single-line block with explicit parameter calling method" do
    assert_offense <<~RUBY
      items.map { |item| item.name }
    RUBY
  end

  test "registers offense for single-line block with predicate method" do
    assert_offense <<~RUBY
      users.select { |user| user.active? }
    RUBY
  end

  test "registers offense for single-line block passing parameter as argument" do
    assert_offense <<~RUBY
      items.each { |item| process(item) }
    RUBY
  end

  test "registers offense for single-line block with short parameter name" do
    assert_offense <<~RUBY
      numbers.map { |n| n.to_s }
    RUBY
  end

  test "registers offense for block with multiple references to parameter" do
    assert_offense <<~'RUBY'
      items.map { |item| "#{item.name}: #{item.age}" }
    RUBY
  end

  test "autocorrects method call on parameter" do
    assert_correction \
      "items.map { |item| item.name }\n",
      "items.map { it.name }\n"
  end

  test "autocorrects predicate method on parameter" do
    assert_correction \
      "users.select { |user| user.active? }\n",
      "users.select { it.active? }\n"
  end

  test "autocorrects parameter passed as argument" do
    assert_correction \
      "items.each { |item| process(item) }\n",
      "items.each { process(it) }\n"
  end

  test "autocorrects multiple references to parameter" do
    original = <<~'RUBY'
      items.map { |item| "#{item.name}: #{item.age}" }
    RUBY

    corrected = <<~'RUBY'
      items.map { "#{it.name}: #{it.age}" }
    RUBY

    assert_correction original, corrected
  end

  test "autocorrects short parameter name" do
    assert_correction \
      "numbers.map { |n| n.to_s }\n",
      "numbers.map { it.to_s }\n"
  end

  test "does not register offense for multi-line do/end block" do
    assert_no_offense <<~RUBY
      items.map do |item|
        item.name
      end
    RUBY
  end

  test "does not register offense for block with multiple parameters" do
    assert_no_offense <<~RUBY
      hash.each { |key, value| puts key }
    RUBY
  end

  test "does not register offense for block with no parameters" do
    assert_no_offense <<~RUBY
      items.each { puts "hello" }
    RUBY
  end

  test "does not register offense for block already using it" do
    assert_no_offense <<~RUBY
      items.map { it.name }
    RUBY
  end

  test "does not crash on a single-parameter block with no body" do
    assert_no_offense "items.map { |x| }"
  end

  test "does not register offense for lambda literal" do
    assert_no_offense <<~RUBY
      double = ->(number) { number * 2 }
    RUBY
  end

  test "does not register offense for lambda" do
    assert_no_offense <<~RUBY
      double = lambda { |number| number * 2 }
    RUBY
  end

  test "does not register offense for proc" do
    assert_no_offense <<~RUBY
      greet = proc { |name| puts name }
    RUBY
  end

  test "does not register offense for Proc.new" do
    assert_no_offense <<~RUBY
      greet = Proc.new { |name| puts name }
    RUBY
  end
end
