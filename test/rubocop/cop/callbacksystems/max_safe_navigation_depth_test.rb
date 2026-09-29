require "test_helper"

class RuboCop::Cop::Callbacksystems::MaxSafeNavigationDepthTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::MaxSafeNavigationDepth

  test "allows a safe navigation that stands alone in the file" do
    assert_no_offense <<~RUBY
      user&.name
    RUBY
  end

  test "allows a single safe-navigation link" do
    assert_no_offense <<~RUBY
      value = account&.owner
    RUBY
  end

  test "allows two safe-navigation links" do
    assert_no_offense <<~RUBY
      value = account&.owner&.name
    RUBY
  end

  test "allows three safe-navigation links at the default maximum" do
    assert_no_offense <<~RUBY
      value = account&.owner&.address&.city
    RUBY
  end

  test "allows a long plain method chain" do
    assert_no_offense <<~RUBY
      value = account.owner.address.city.zip
    RUBY
  end

  test "allows a chain broken by a non-safe link" do
    assert_no_offense <<~RUBY
      value = account&.owner.address
    RUBY
  end

  test "counts safe-navigation links across a chain broken by plain links" do
    offenses = assert_offense <<~RUBY
      value = account&.owner.name&.first&.upcase&.strip
    RUBY
    assert_includes offenses.first.message, "depth 4 exceeds maximum 3"
  end

  test "registers offense for four safe-navigation links" do
    offenses = assert_offense <<~RUBY
      value = account&.owner&.address&.city&.zip
    RUBY
    assert_includes offenses.first.message, "depth 4 exceeds maximum 3"
  end

  test "registers a single offense for a very deep chain" do
    assert_offense <<~RUBY, count: 1
      value = object&.foo&.bar&.baz&.qux&.quux
    RUBY
  end

  test "measures a mixed chain deeper than Ruby's call stack without recursion" do
    links = 2_000.times.map { it.even? ? "&.next" : ".next" }.join
    source = RuboCop::ProcessedSource.new("object#{links}\n", RUBY_VERSION.to_f)
    context = RuboCop::Cop::Callbacksystems::MaxSafeNavigationDepth::NavigationContext.new

    assert RuboCop::Cop::Callbacksystems::MaxSafeNavigationDepth::NavigationChain
      .new(source.ast, context, max_depth: 3).offense
  end

  test "registers one offense when plain calls finish a deep safe-navigation chain" do
    assert_offense <<~RUBY, count: 1
      value = account&.owner&.address&.city&.zip.to_s.strip
    RUBY
  end

  test "registers offense inside a method call argument" do
    assert_offense <<~RUBY
      render account&.owner&.address&.city&.zip
    RUBY
  end
end
