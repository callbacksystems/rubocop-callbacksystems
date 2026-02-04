require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDeclarativeCollectionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDeclarativeCollections

  test "registers offense for each with << to local array" do
    assert_offense <<~RUBY
      results = []
      items.each { |item| results << item.name }
    RUBY
  end

  test "registers offense for each with << to instance variable array" do
    assert_offense <<~RUBY
      @results = []
      items.each { |item| @results << item }
    RUBY
  end

  test "registers offense for each with conditional <<" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        results << item if item.active?
      end
    RUBY
  end

  test "registers offense for each with if/else <<" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        if item.active?
          results << item.name
        end
      end
    RUBY
  end

  test "allows each without <<" do
    assert_no_offense <<~RUBY
      items.each { |item| process(item) }
    RUBY
  end

  test "allows each with << to non-empty array" do
    assert_no_offense <<~RUBY
      results = [1, 2, 3]
      items.each { |item| results << item }
    RUBY
  end

  test "allows map" do
    assert_no_offense <<~RUBY
      results = items.map(&:name)
    RUBY
  end

  test "allows select" do
    assert_no_offense <<~RUBY
      results = items.select(&:active?)
    RUBY
  end

  test "allows each_with_object" do
    assert_no_offense <<~RUBY
      items.each_with_object([]) { |item, arr| arr << item.name }
    RUBY
  end

  test "allows tap pattern" do
    assert_no_offense <<~RUBY
      [].tap do |results|
        items.each { |item| results << item }
      end
    RUBY
  end

  test "registers offense for numblock with <<" do
    assert_offense <<~RUBY
      results = []
      items.each { results << _1.name }
    RUBY
  end
end
