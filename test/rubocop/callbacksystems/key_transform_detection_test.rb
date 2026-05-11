require "test_helper"

class RuboCop::Callbacksystems::KeyTransformDetectionTest < CopTestCase
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
end
