require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::RangesTest < HelpersTestCase
  test "line_removal_range_for covers the full line and its trailing newline" do
    source = "  foo = 1\nbar\n"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    node = processed.ast.children.first
    range = Helpers.line_removal_range_for(node)

    assert_equal "  foo = 1\n", range.source
  end

  test "line_removal_range_for stops at end of source when no trailing newline" do
    source = "  foo = 1"
    processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    range = Helpers.line_removal_range_for(processed.ast)

    assert_equal "  foo = 1", range.source
  end
end
