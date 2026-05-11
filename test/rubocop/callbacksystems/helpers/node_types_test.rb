require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::NodeTypesTest < HelpersTestCase
  test "any_block_type? returns true for block nodes" do
    ast = parse("items.each { |x| x }").ast
    block_node = ast.each_node(:block).first

    assert Helpers.any_block_type?(block_node)
  end

  test "any_block_type? returns false for non-block nodes" do
    ast = parse("foo").ast

    assert_not Helpers.any_block_type?(ast)
  end

  test "any_block_type? returns false for nil" do
    assert_not Helpers.any_block_type?(nil)
  end

  test "constant_name returns simple constant name" do
    node = parse("Foo").ast

    assert_equal "Foo", Helpers.constant_name(node)
  end

  test "constant_name returns namespaced constant" do
    node = parse("Foo::Bar::Baz").ast

    assert_equal "Foo::Bar::Baz", Helpers.constant_name(node)
  end

  test "constant_name returns nil for nil input" do
    assert_nil Helpers.constant_name(nil)
  end
end
