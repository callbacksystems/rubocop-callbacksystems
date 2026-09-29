require "test_helper"

class RuboCop::Callbacksystems::Helpers::CorrectionsTest < HelpersTestCase
  test "replace_expression replaces an ordinary variable value" do
    processed = processed_source("value = original\nconsume(value)\n")

    assert_equal "value = original\nconsume(replacement)\n", rewritten(processed, with: "replacement")
  end

  test "replace_expression expands a shorthand keyword without renaming its key" do
    processed = processed_source("value = original\nconsume(value:)\n")

    assert_equal "value = original\nconsume(value: replacement)\n", rewritten(processed, with: "replacement")
  end

  test "replace_expression replaces a root expression without a parent" do
    processed = processed_source("value = original\n")
    corrector = RuboCop::Cop::Corrector.new(processed)

    Helpers.replace_expression(corrector, processed.ast, with: "replacement")

    assert_equal "replacement\n", corrector.rewrite
  end

  private
    def rewritten(processed, with:)
      corrector = RuboCop::Cop::Corrector.new(processed)
      Helpers.replace_expression(corrector, processed.ast.each_node(:lvar).first, with:)
      corrector.rewrite
    end
end
