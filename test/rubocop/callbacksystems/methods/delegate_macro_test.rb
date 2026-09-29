require "test_helper"

class RuboCop::Callbacksystems::Methods::DelegateMacroTest < ActiveSupport::TestCase
  include SourceParsing

  test "macro? returns true for a delegate call with options" do
    assert macro_for("delegate :size, to: :node").macro?
  end

  test "macro? returns false for a delegate call without options" do
    assert_not macro_for("delegate :size").macro?
  end

  test "macro? returns false for a delegate call without arguments" do
    assert_not macro_for("delegate").macro?
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

  test "target returns nil for a delegation naming no receiver" do
    assert_nil macro_for("delegate :size, private: true").target
  end

  test "target returns the dotted receiver of a nested delegation" do
    assert_equal "config.postgres", macro_for("delegate :size, to: \"config.postgres\"").target
  end

  test "target returns the constant receiver" do
    assert_equal "Pay::Currency", macro_for("delegate :size, to: Pay::Currency").target
  end

  test "target returns nil when the receiver is not a plain name" do
    assert_nil macro_for("delegate :size, to: node.config").target
  end

  test "target returns nil when a following keyword splat may replace it" do
    assert_nil macro_for("delegate :size, to: :node, **OPTIONS").target
  end

  test "target_method_names returns the names read on the target" do
    macro = macro_for("delegate :size, \"length\", to: :node, prefix: true")

    assert_equal %i[ size length ], macro.target_method_names
  end

  test "target_method_names returns nil when a delegated name is dynamic" do
    assert_nil macro_for("delegate :size, *METHODS, to: :node").target_method_names
  end

  test "target_method_names returns nil for delegate_missing_to" do
    assert_nil macro_for("delegate_missing_to :node").target_method_names
  end

  test "defined_method_names returns unprefixed names" do
    assert_equal %i[ size length ], macro_for("delegate :size, :length, to: :node").defined_method_names
  end

  test "defined_method_names applies the target as a true prefix" do
    assert_equal [ :node_size ], macro_for("delegate :size, to: :node, prefix: true").defined_method_names
  end

  test "defined_method_names applies a literal custom prefix" do
    assert_equal [ :entry_size ], macro_for("delegate :size, to: :node, prefix: :entry").defined_method_names
  end

  test "defined_method_names returns nil for a dynamic prefix" do
    assert_nil macro_for("delegate :size, to: :node, prefix: method_prefix").defined_method_names
  end

  test "defined_method_names returns nil when a keyword splat can provide the prefix" do
    assert_nil macro_for("delegate :size, to: :node, **OPTIONS").defined_method_names
  end

  test "defined_method_names returns the methods installed by delegate_missing_to" do
    assert_equal %i[ method_missing respond_to_missing? ],
      macro_for("delegate_missing_to :node").defined_method_names
  end

  test "defined_method_names returns nil for a different macro" do
    assert_nil macro_for("attr_reader :name").defined_method_names
  end

  test "defined_method_names returns nil when a true prefix has no literal target" do
    assert_nil macro_for("delegate :size, to: node.config, prefix: true").defined_method_names
  end

  test "defined_method_names returns nil when a true prefix has a constant target" do
    assert_nil macro_for("delegate :size, to: Pay::Currency, prefix: true").defined_method_names
  end

  test "private? returns true when the private option is set" do
    assert macro_for("delegate :size, to: :node, private: true").private?
  end

  test "private? returns false when the private option is missing" do
    assert_not macro_for("delegate :size, to: :node").private?
  end

  test "private? returns false when the private option is dynamic" do
    assert_not macro_for("delegate :size, to: :node, private: private_delegates?").private?
  end

  test "private? returns false when the private option is explicitly false" do
    assert_not macro_for("delegate :size, to: :node, private: false").private?
  end

  test "plain? returns true for a public delegate with default options" do
    assert macro_for("delegate :size, to: :node").plain?(private: false)
  end

  test "plain? returns true for a private delegate with inactive options" do
    assert macro_for("delegate :size, to: :node, prefix: false, allow_nil: nil, private: true").plain?(private: true)
  end

  test "plain? returns false when prefix is active" do
    assert_not macro_for("delegate :size, to: :node, prefix: true").plain?(private: false)
  end

  test "plain? returns false when allow_nil is active" do
    assert_not macro_for("delegate :size, to: :node, allow_nil: true").plain?(private: false)
  end

  test "plain? returns false when visibility is dynamic" do
    assert_not macro_for("delegate :size, to: :node, private: private_delegates?").plain?(private: false)
  end

  test "plain? returns false when a keyword splat can supply options" do
    assert_not macro_for("delegate :size, to: :node, **OPTIONS").plain?(private: false)
  end

  test "private_option_known? returns true without a keyword splat" do
    assert macro_for("delegate :size, to: :node").private_option_known?
  end

  test "private_option_known? returns true when an explicit option follows a keyword splat" do
    assert macro_for("delegate :size, **OPTIONS, private: true").private_option_known?
  end

  test "private_option_known? returns false when a keyword splat may provide the option" do
    assert_not macro_for("delegate :size, **OPTIONS").private_option_known?
  end

  test "private_option returns the option pair" do
    assert_equal "private: false", macro_for("delegate :size, private: false").private_option.source
  end

  test "private_option returns nil when the option is missing" do
    assert_nil macro_for("delegate :size, to: :node").private_option
  end

  test "private_option returns nil when the macro has no options" do
    assert_nil macro_for("delegate :size").private_option
  end

  test "private_option returns the last explicit value" do
    macro = macro_for("delegate :size, private: false, private: true")

    assert_equal "private: true", macro.private_option.source
  end

  test "private_option returns nil when a following keyword splat may replace it" do
    assert_nil macro_for("delegate :size, private: true, **OPTIONS").private_option
  end

  test "private_option returns a final duplicate option that follows a keyword splat" do
    macro = macro_for("delegate :size, private: true, **OPTIONS, private: true")

    assert_equal "private: true", macro.private_option.source
  end

  test "first_option returns the leading option pair" do
    assert_equal "to: :node", macro_for("delegate :size, to: :node, private: true").first_option.source
  end

  test "last_option returns the trailing option pair" do
    assert_equal "private: true", macro_for("delegate :size, to: :node, private: true").last_option.source
  end

  test "last_option returns a trailing keyword splat" do
    assert_equal "**OPTIONS", macro_for("delegate :size, **OPTIONS").last_option.source
  end

  private
    def macro_for(source)
      RuboCop::Callbacksystems::Methods::DelegateMacro.new(processed_source(source).ast)
    end
end
