require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferSymbolizeKeysTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferSymbolizeKeys

  test "registers offense for transform_keys with to_sym block pass" do
    assert_offense <<~RUBY
      hash.transform_keys(&:to_sym)
    RUBY
  end

  test "registers offense for transform_keys with to_sym block" do
    assert_offense <<~RUBY
      hash.transform_keys { |k| k.to_sym }
    RUBY
  end

  test "autocorrects block pass to symbolize_keys" do
    assert_correction "hash.transform_keys(&:to_sym)", "hash.symbolize_keys"
  end

  test "autocorrects block to symbolize_keys" do
    assert_correction "hash.transform_keys { |k| k.to_sym }", "hash.symbolize_keys"
  end

  test "autocorrects with method chain" do
    assert_correction "data.slice(:a, :b).transform_keys(&:to_sym)", "data.slice(:a, :b).symbolize_keys"
  end

  test "does not register offense for transform_keys with other block pass" do
    assert_no_offense <<~RUBY
      hash.transform_keys(&:upcase)
    RUBY
  end

  test "does not register offense for transform_keys with complex block" do
    assert_no_offense <<~RUBY
      hash.transform_keys { |k| :"prefix_\#{k}" }
    RUBY
  end

  test "does not register offense for transform_values" do
    assert_no_offense <<~RUBY
      hash.transform_values(&:to_sym)
    RUBY
  end
end
