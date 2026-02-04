require "test_helper"

class RuboCop::Cop::Callbacksystems::NoTapCollectionBuildingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoTapCollectionBuilding

  test "registers offense for tap on empty array with push" do
    assert_offense <<~RUBY
      [].tap { |arr| items.each { |i| arr << i.name } }
    RUBY
  end

  test "registers offense for tap on empty array with append" do
    assert_offense <<~RUBY
      [].tap { |arr| arr.push(item) }
    RUBY
  end

  test "registers offense for tap on empty hash with bracket assignment" do
    assert_offense <<~RUBY
      {}.tap { |h| items.each { |i| h[i.id] = i } }
    RUBY
  end

  test "registers offense for tap on empty hash with store" do
    assert_offense <<~RUBY
      {}.tap { |h| h.store(key, value) }
    RUBY
  end

  test "allows tap for logging" do
    assert_no_offense <<~RUBY
      user.tap { |u| logger.info(u.id) }
    RUBY
  end

  test "allows tap for object configuration" do
    assert_no_offense <<~RUBY
      User.new.tap { |u| u.name = "John" }
    RUBY
  end

  test "allows tap on non-empty array" do
    assert_no_offense <<~RUBY
      [1, 2, 3].tap { |arr| arr << 4 }
    RUBY
  end

  test "allows tap without mutations" do
    assert_no_offense <<~RUBY
      [].tap { |arr| puts arr.size }
    RUBY
  end

  test "allows map instead of tap" do
    assert_no_offense <<~RUBY
      items.map { it.name }
    RUBY
  end

  test "registers offense for Set.new.tap" do
    assert_offense <<~RUBY
      Set.new.tap { |s| items.each { |i| s << i } }
    RUBY
  end

  test "registers offense for Hash.new.tap" do
    assert_offense <<~RUBY
      Hash.new.tap { |h| items.each { |i| h[i.id] = i } }
    RUBY
  end

  test "registers offense for Array.new.tap" do
    assert_offense <<~RUBY
      Array.new.tap { |arr| items.each { |i| arr << i } }
    RUBY
  end

  test "registers offense for Hash.new with block and tap" do
    assert_offense <<~RUBY
      Hash.new { |h, k| h[k] = [] }.tap { |h| items.each { |i| h[i.type] << i } }
    RUBY
  end
end
