require "test_helper"

class RuboCop::Callbacksystems::DelegateMacroTest < ActiveSupport::TestCase
  test "macro? returns true for a delegate call with options" do
    assert macro_for("delegate :size, to: :node").macro?
  end

  test "macro? returns false for a delegate call without options" do
    assert_not macro_for("delegate :size").macro?
  end

  test "macro? returns false for a delegate call with a receiver" do
    assert_not macro_for("other.delegate :size, to: :node").macro?
  end

  test "macro? returns false for other macros" do
    assert_not macro_for("validates :name, presence: true").macro?
  end

  test "target returns the symbol receiver" do
    assert_equal "node", macro_for("delegate :size, to: :node").target
  end

  test "target returns the dotted receiver of a nested delegation" do
    assert_equal "config.postgres", macro_for("delegate :size, to: \"config.postgres\"").target
  end

  test "target returns nil when the receiver is not a plain name" do
    assert_nil macro_for("delegate :size, to: SOME_CONSTANT").target
  end

  test "private? returns true when the private option is set" do
    assert macro_for("delegate :size, to: :node, private: true").private?
  end

  test "private? returns false when the private option is missing" do
    assert_not macro_for("delegate :size, to: :node").private?
  end

  test "first_option returns the leading option pair" do
    assert_equal "to: :node", macro_for("delegate :size, to: :node, private: true").first_option.source
  end

  test "last_option returns the trailing option pair" do
    assert_equal "private: true", macro_for("delegate :size, to: :node, private: true").last_option.source
  end

  private
    def macro_for(source)
      RuboCop::Callbacksystems::DelegateMacro.new(RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast)
    end
end
