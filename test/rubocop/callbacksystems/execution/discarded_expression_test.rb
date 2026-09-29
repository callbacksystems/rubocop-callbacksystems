require "test_helper"

class RuboCop::Callbacksystems::Execution::DiscardedExpressionTest < ActiveSupport::TestCase
  include SourceParsing

  test "discarded? is true for a root expression" do
    assert RuboCop::Callbacksystems::Execution::DiscardedExpression.new(processed_source("work").ast).discarded?
  end

  test "discarded? is true for an expression with a following sequence entry" do
    expression = processed_source("begin\n  work\n  finish\nend").ast.children.first

    assert RuboCop::Callbacksystems::Execution::DiscardedExpression.new(expression).discarded?
  end

  test "discarded? is false for the final value of an assignment" do
    expression = processed_source("result = begin\n  work\nend").ast.each_node(:send).first

    assert_not RuboCop::Callbacksystems::Execution::DiscardedExpression.new(expression).discarded?
  end

  test "discarded? follows a nested definition body out to the root" do
    expression = processed_source("class Outer\n  class Inner\n  end\nend").ast.each_node(:class).to_a.last

    assert RuboCop::Callbacksystems::Execution::DiscardedExpression.new(expression).discarded?
  end

  test "discarded? is false when an outer definition carries the value into an assignment" do
    source = processed_source("result = class Outer\n  class Inner\n  end\nend")
    expression = source.ast.each_node(:class).to_a.last

    assert_not RuboCop::Callbacksystems::Execution::DiscardedExpression.new(expression).discarded?
  end

  test "discarded? is false when a call observes the expression" do
    expression = processed_source("register(class Inner\nend)").ast.each_node(:class).first

    assert_not RuboCop::Callbacksystems::Execution::DiscardedExpression.new(expression).discarded?
  end
end
