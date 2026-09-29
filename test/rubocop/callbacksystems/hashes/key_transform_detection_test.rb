require "test_helper"

class RuboCop::Callbacksystems::Hashes::KeyTransformDetectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferStringifyKeys

  test "included extends AutoCorrector on the including class" do
    assert_includes self.class.cop_class.singleton_class.ancestors, RuboCop::Cop::AutoCorrector
  end

  test "on_send detects transform_keys with block pass" do
    assert_offense(<<~RUBY)
      hash.transform_keys(&:to_s)
    RUBY
  end

  test "on_block detects transform_keys with block" do
    assert_offense(<<~RUBY)
      hash.transform_keys { |k| k.to_s }
    RUBY
  end

  test "on_numblock detects transform_keys with a numbered parameter" do
    assert_offense(<<~RUBY)
      hash.transform_keys { _1.to_s }
    RUBY
  end

  test "on_itblock detects transform_keys with an it parameter" do
    assert_offense(<<~RUBY)
      hash.transform_keys { it.to_s }
    RUBY
  end

  test "on_block leaves a transform_keys block with an empty body" do
    assert_no_offense(<<~RUBY)
      hash.transform_keys { |k| }
    RUBY
  end

  test "on_block leaves a transform_keys block calling something other than its parameter" do
    assert_no_offense(<<~RUBY)
      hash.transform_keys { |k| default_key }
    RUBY
  end

  test "on_block leaves a destructured parameter alone" do
    assert_no_offense(<<~RUBY)
      hash.transform_keys { |(key, value)| key.to_s }
    RUBY
  end

  test "on_block leaves arguments passed to the conversion method alone" do
    assert_no_offense(<<~RUBY)
      hash.transform_keys { |key| key.to_s(16) }
    RUBY
  end
end
