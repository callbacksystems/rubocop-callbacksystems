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

  test "registers offense for mutation reached through safe navigation" do
    assert_offense <<~RUBY
      [].tap { |items| items&.push(value) }
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

  test "allows a receiverless mutation call inside tap" do
    assert_no_offense <<~RUBY
      [].tap { |items| push(items) }
    RUBY
  end

  test "allows a tap block that mutates a different collection" do
    assert_no_offense <<~RUBY
      [].tap { |items| audit_log << items.size }
    RUBY
  end

  test "allows a tap block that mutates a collection returned by the yielded one" do
    assert_no_offense <<~RUBY
      {}.tap { |attributes| attributes.keys << :missing }
      [].tap { |items| items.dup.push(value) }
    RUBY
  end

  test "allows a shadowed block argument that mutates a different collection" do
    assert_no_offense <<~RUBY
      [].tap do |items|
        collections.each do |items|
          items << value
        end
      end
    RUBY
  end

  test "allows mutations captured by deferred callable blocks" do
    assert_no_offense <<~RUBY
      [].tap do |items|
        -> { items << first }
        lambda { items.push(second) }
        proc { items.append(third) }
        Proc.new { items.store(3, fourth) }
      end
    RUBY
  end

  test "allows mutations captured by dynamically defined methods" do
    assert_no_offense <<~RUBY
      [].tap do |items|
        define_method(:append_later) { items << value }
        define_singleton_method(:store_later) { items.store(0, value) }
      end
    RUBY
  end

  test "registers a mutation run by a class constructor block" do
    assert_offense <<~RUBY
      [].tap do |items|
        Class.new do
          items << value
        end
      end
    RUBY
  end

  test "registers offense for a numbered tap argument" do
    assert_offense <<~RUBY
      [].tap { _1 << value }
    RUBY
  end

  test "registers offense for an it tap argument" do
    assert_offense <<~RUBY
      [].tap { it << value }
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

  test "allows mutating a default that the Hash does not store" do
    assert_no_offense <<~RUBY
      Hash.new { [] }.tap { |groups| groups[key] << value }
      Hash.new { |hash, key| nil }.tap { |groups| groups[key] << value }
      Hash.new { |hash, key| }.tap { |groups| groups[key] << value }
    RUBY
  end

  test "allows a malformed stored default call without a key" do
    assert_no_offense <<~RUBY
      Hash.new { |hash, key| hash.[]=() }.tap { |groups| groups[key] << value }
    RUBY
  end

  test "allows mutating a stored default that is not a collection" do
    assert_no_offense <<~RUBY
      Hash.new { |hash, key| hash[key] = Object.new }.tap { |objects| objects[key] << value }
    RUBY
  end

  test "registers offense for an empty Hash with a default value" do
    assert_offense <<~RUBY
      Hash.new(false).tap { |hash| hash[:ready] = true }
    RUBY
  end

  test "allows tap on an Array constructor that already has entries" do
    assert_no_offense <<~RUBY
      Array.new(3).tap { |items| items << value }
    RUBY
  end

  test "allows tap on a Set constructor that may already have entries" do
    assert_no_offense <<~RUBY
      Set.new(existing).tap { |items| items << value }
    RUBY
  end

  test "allows tap on namespaced collection lookalikes" do
    assert_no_offense <<~RUBY
      Domain::Array.new.tap { |items| items << value }
      Domain::Hash.new.tap { |items| items[:key] = value }
      Domain::Set.new.tap { |items| items << value }
    RUBY
  end

  test "allows a tap on a constructor called without a receiver" do
    assert_no_offense <<~RUBY
      class Report
        def rows
          new.tap { |rows| rows << 1 }
        end
      end
    RUBY
  end
end
