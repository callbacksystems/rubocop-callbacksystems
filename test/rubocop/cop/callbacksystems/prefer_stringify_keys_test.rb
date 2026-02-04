require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferStringifyKeysTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferStringifyKeys

  test "registers offense for transform_keys with to_s block pass" do
    assert_offense <<~RUBY
      hash.transform_keys(&:to_s)
    RUBY
  end

  test "registers offense for transform_keys with to_s block" do
    assert_offense <<~RUBY
      hash.transform_keys { |k| k.to_s }
    RUBY
  end

  test "autocorrects block pass to stringify_keys" do
    assert_correction "hash.transform_keys(&:to_s)", "hash.stringify_keys"
  end

  test "autocorrects block to stringify_keys" do
    assert_correction "hash.transform_keys { |k| k.to_s }", "hash.stringify_keys"
  end

  test "autocorrects with method chain" do
    assert_correction "data.slice(:a, :b).transform_keys(&:to_s)", "data.slice(:a, :b).stringify_keys"
  end

  test "does not register offense for transform_keys with other block pass" do
    assert_no_offense <<~RUBY
      hash.transform_keys(&:upcase)
    RUBY
  end

  test "does not register offense for transform_keys with complex block" do
    assert_no_offense <<~RUBY
      hash.transform_keys { |k| "prefix_\#{k}" }
    RUBY
  end

  test "does not register offense for transform_values" do
    assert_no_offense <<~RUBY
      hash.transform_values(&:to_s)
    RUBY
  end
end
