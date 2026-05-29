require "test_helper"

class RuboCop::Cop::Callbacksystems::NoHashWithDefaultBlockTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoHashWithDefaultBlock

  test "flags Hash.new with default block initializing to empty array" do
    assert_offense <<~RUBY
      groups = Hash.new { |h, k| h[k] = [] }
    RUBY
  end

  test "flags Hash.new with default block initializing to empty hash" do
    assert_offense <<~RUBY
      cache = Hash.new { |h, k| h[k] = {} }
    RUBY
  end

  test "flags Hash.new with default block initializing to Set.new" do
    assert_offense <<~RUBY
      tags = Hash.new { |h, k| h[k] = Set.new }
    RUBY
  end

  test "flags Hash.new with default block initializing to Hash.new" do
    assert_offense <<~RUBY
      nested = Hash.new { |h, k| h[k] = Hash.new }
    RUBY
  end

  test "flags Hash.new with default block passed to each_with_object" do
    assert_offense <<~RUBY
      items.each_with_object(Hash.new { |h, k| h[k] = [] }) do |item, groups|
        groups[item.type] << item
      end
    RUBY
  end

  test "flags Hash.new with default block when chained with tap" do
    assert_offense <<~RUBY
      Hash.new { |h, k| h[k] = [] }.tap { |h| things.each { |t| h[t.type] << t } }
    RUBY
  end

  test "ignores Hash.new with a default value (not a block)" do
    assert_no_offense <<~RUBY
      counter = Hash.new(0)
    RUBY
  end

  test "ignores Hash.new with no default at all" do
    assert_no_offense <<~RUBY
      result = Hash.new
    RUBY
  end

  test "ignores Hash.new with a block that does not initialize to an empty collection" do
    assert_no_offense <<~RUBY
      memo = Hash.new { |h, k| h[k] = compute(k) }
    RUBY
  end

  test "ignores Hash.new with a block returning without assigning" do
    assert_no_offense <<~RUBY
      memo = Hash.new { |h, k| compute(k) }
    RUBY
  end

  test "ignores blocks on other receivers" do
    assert_no_offense <<~RUBY
      Cache.new { |h, k| h[k] = [] }
    RUBY
  end
end
