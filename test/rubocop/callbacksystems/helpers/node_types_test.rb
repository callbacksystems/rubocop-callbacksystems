require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::NodeTypesTest < HelpersTestCase
  test "any_block_type? returns true for block nodes" do
    ast = processed_source("items.each { |x| x }").ast
    block_node = ast.each_node(:block).first

    assert Helpers.any_block_type?(block_node)
  end

  test "any_block_type? returns false for non-block nodes" do
    ast = processed_source("foo").ast

    assert_not Helpers.any_block_type?(ast)
  end

  test "any_block_type? returns false for nil" do
    assert_not Helpers.any_block_type?(nil)
  end

  test "bare_send? returns true for receiver-less send" do
    node = processed_source("foo(1)").ast

    assert Helpers.bare_send?(node)
  end

  test "bare_send? returns false when there is a receiver" do
    node = processed_source("obj.foo").ast

    assert_not Helpers.bare_send?(node)
  end

  test "bare_send? returns false for non-send nodes" do
    node = processed_source("42").ast

    assert_not Helpers.bare_send?(node)
  end

  test "bare_send? returns false for nil" do
    assert_not Helpers.bare_send?(nil)
  end

  test "reads_variable? returns true when the node reads the given local variable" do
    ast = processed_source("value = 1\nvalue").ast
    lvar_node = ast.each_node(:lvar).first

    assert Helpers.reads_variable?(lvar_node, :value)
  end

  test "reads_variable? returns true when the node reads the given instance variable" do
    node = processed_source("@count").ast

    assert Helpers.reads_variable?(node, :@count)
  end

  test "reads_variable? returns false for a different variable name" do
    node = processed_source("@count").ast

    assert_not Helpers.reads_variable?(node, :@total)
  end

  test "reads_variable? returns false for non-variable nodes" do
    node = processed_source("foo").ast

    assert_not Helpers.reads_variable?(node, :foo)
  end

  test "reads_variable? returns false for nil" do
    assert_not Helpers.reads_variable?(nil, :value)
  end

  test "constant_name_of returns simple constant name" do
    node = processed_source("Foo").ast

    assert_equal "Foo", Helpers.constant_name_of(node)
  end

  test "constant_name_of returns namespaced constant" do
    node = processed_source("Foo::Bar::Baz").ast

    assert_equal "Foo::Bar::Baz", Helpers.constant_name_of(node)
  end

  test "constant_name_of returns nil for nil input" do
    assert_nil Helpers.constant_name_of(nil)
  end
end
