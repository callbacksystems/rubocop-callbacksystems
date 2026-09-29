require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferItBlockParameterTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferItBlockParameter

  test "allows a parameter read from inside a block of its own" do
    assert_no_offense <<~RUBY
      names.index { |name| labels.any? { |label| name.include?(label) } }
    RUBY
  end

  test "allows a parameter read from inside a block that takes no parameter" do
    assert_no_offense <<~RUBY
      names.index { |name| labels.any? { name.present? } }
    RUBY
  end

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

  test "expands a shorthand keyword so its name stays unchanged" do
    assert_correction \
      "items.each { |item| process(item:) }\n",
      "items.each { process(item: it) }\n"
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

  test "does not register offense for a splat parameter" do
    assert_no_offense <<~RUBY
      messages.each { |*message| reports << message }
    RUBY
  end

  test "does not register offense for an optional parameter" do
    assert_no_offense <<~RUBY
      values.each { |value = nil| results << value }
    RUBY
  end

  test "does not register offense for block with no parameters" do
    assert_no_offense <<~RUBY
      items.each { puts "hello" }
    RUBY
  end

  test "does not register offense when the parameter is reassigned" do
    assert_no_offense <<~RUBY
      items.map { |item| item = transform(item); item }
    RUBY
  end

  test "does not register offense when a compound assignment rewrites the parameter" do
    assert_no_offense <<~RUBY
      numbers.map { |number| number += 1; number }
    RUBY
  end

  test "does not register offense when pattern matching rewrites the parameter" do
    assert_no_offense <<~RUBY
      pairs.map { |pair| pair => [ pair, value ]; pair }
    RUBY
  end

  test "does not register offense for block already using it" do
    assert_no_offense <<~RUBY
      items.map { it.name }
    RUBY
  end

  test "does not register offense for a numbered block parameter" do
    assert_no_offense <<~RUBY
      items.map { _1.name }
    RUBY
  end

  test "does not crash on a single-parameter block with no body" do
    assert_no_offense "items.map { |x| }"
  end

  test "does not autocorrect an unused parameter because removing it changes the block arity" do
    assert_uncorrectable_offense "items.map { |item| 1 }"
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

  test "does not register offense for define_method" do
    assert_no_offense <<~RUBY
      define_method(:double) { |number| number * 2 }
    RUBY
  end

  test "does not register offense for define_singleton_method with unused parameter" do
    assert_no_offense <<~RUBY
      object.define_singleton_method(:call) { |_client| response }
    RUBY
  end

  test "does not register offense for Proc.new" do
    assert_no_offense <<~RUBY
      greet = Proc.new { |name| puts name }
    RUBY
  end

  test "rewrites a block whose body is the parameter alone" do
    assert_correction "items.each { |item| item }\n", "items.each { it }\n"
  end

  test "leaves the other local variables a block body reads" do
    assert_correction "items.each { |item| total + item }\n", "items.each { total + it }\n"
  end

  test "leaves a block reading an outer local named it alone" do
    assert_no_offense <<~RUBY
      it = 10
      numbers.map { |number| number + it }
    RUBY
  end

  test "leaves a block calling a method named it alone" do
    assert_no_offense <<~RUBY
      numbers.map { |number| number + it }
    RUBY
  end

  test "leaves a block assigning a pattern variable named it alone" do
    assert_no_offense <<~RUBY
      numbers.map { |number| [ number ] => [ it ]; number }
    RUBY
  end

  test "leaves a block with an inner block-local named it alone" do
    assert_no_offense <<~RUBY
      numbers.map { |number| values.each { |value; it| value }; number }
    RUBY
  end
end
