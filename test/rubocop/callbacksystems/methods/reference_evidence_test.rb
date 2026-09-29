require "test_helper"

class RuboCop::Callbacksystems::Methods::ReferenceEvidenceTest < ActiveSupport::TestCase
  include SourceParsing

  setup do
    @root = processed_source(<<~'RUBY').ast
      target(:literal, &callback)
      receiver&.public_send(:dynamic)
      alias replacement original
      "prefix_#{name}"
    RUBY
    @evidence = evidence_for(@root)
  end

  test "for shares the evidence for one AST" do
    assert_same @evidence, evidence_for(@root)
    assert_not_same @evidence, evidence_for(processed_source("other\n").ast)
  end

  test "calls preserve send and csend source order" do
    assert_equal [ "target(:literal, &callback)", "callback", "receiver&.public_send(:dynamic)", "receiver", "name" ],
      @evidence.calls.map(&:source)
  end

  test "block_passes return method block passes" do
    assert_equal [ "&callback" ], @evidence.block_passes.map(&:source)
  end

  test "alias_nodes return alias declarations" do
    assert_equal [ "alias replacement original" ], @evidence.alias_nodes.map(&:source)
  end

  test "literals return static strings and symbols" do
    assert_equal [ ":literal", ":dynamic", "replacement", "original", "prefix_" ], @evidence.literals.map(&:source)
  end

  test "interpolated_literals return dynamic strings and symbols" do
    assert_equal [ %q("prefix_#{name}") ], @evidence.interpolated_literals.map(&:source)
  end

  test "macro_referenced_methods share the source macro reading" do
    root = processed_source("before_save :normalize\n").ast
    evidence = evidence_for(root)

    assert_equal Set[:normalize], evidence.macro_referenced_methods
    assert_same evidence.macro_referenced_methods, evidence.macro_referenced_methods
  end

  test "literal_method_names recognize symbol names and words inside strings" do
    root = processed_source(%q([:save!, :"[]", "finish? save! update=", "bad\xFFname"])).ast
    evidence = evidence_for(root)

    assert_equal Set["save!", "[]", "finish?", "update=", "bad", "name"], evidence.literal_method_names
    assert_same evidence.literal_method_names, evidence.literal_method_names
  end

  private
    def evidence_for(root)
      RuboCop::Callbacksystems::Methods::ReferenceEvidence.for(root)
    end
end
