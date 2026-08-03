require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::NodeTypesTest < HelpersTestCase
  test "declaration_macro? returns true for a receiver-less declaration macro" do
    node = processed_source("delegate :size, to: :node").ast

    assert Helpers.declaration_macro?(node)
  end

  test "declaration_macro? returns false for other receiver-less calls" do
    node = processed_source("validates :name").ast

    assert_not Helpers.declaration_macro?(node)
  end

  test "declaration_macro? returns false when the macro has a receiver" do
    node = processed_source("other.attr_reader :node").ast

    assert_not Helpers.declaration_macro?(node)
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

  test "singleton_section? returns true for class << self" do
    node = processed_source("class << self\nend").ast

    assert Helpers.singleton_section?(node)
  end

  test "singleton_section? returns false for a singleton class of another object" do
    node = processed_source("class << other\nend").ast

    assert_not Helpers.singleton_section?(node)
  end

  test "singleton_section? returns false for nil" do
    assert_not Helpers.singleton_section?(nil)
  end

  test "definition_identifier? returns true for the constant a class definition names" do
    node = processed_source("class Foo::Bar\nend").ast.identifier

    assert Helpers.definition_identifier?(node)
  end

  test "definition_identifier? returns false for a superclass reference" do
    node = processed_source("class Foo < Bar\nend").ast.parent_class

    assert_not Helpers.definition_identifier?(node)
  end

  test "definition_identifier? returns false for a constant read in a body" do
    node = processed_source("class Foo\n  Bar\nend").ast.body

    assert_not Helpers.definition_identifier?(node)
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

  test "class_with_body? returns true for a class holding methods" do
    node = processed_source("class Foo\n  def bar; end\nend").ast

    assert Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a class with no body" do
    node = processed_source("class Foo < Bar; end").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "class_with_body? returns true for a class builder taking a block" do
    node = processed_source("Entry = Data.define(:sku) do\n  def total; end\nend").ast

    assert Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a class builder with no block" do
    node = processed_source("Entry = Data.define(:sku, :quantity)").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a constant that builds nothing" do
    node = processed_source("FORMATS = [ :json ].freeze").ast

    assert_not Helpers.class_with_body?(node)
  end

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

  test "holds_heredoc? is true for a literal built from a heredoc" do
    node = processed_source(<<~RUBY).ast
      PROBES = [
        <<~SQL
          select 1
        SQL
      ].freeze
    RUBY

    assert Helpers.holds_heredoc?(node)
  end

  test "holds_heredoc? is true for the heredoc itself" do
    node = processed_source(<<~RUBY).ast.expression
      BODY = <<~SQL
        select 1
      SQL
    RUBY

    assert Helpers.holds_heredoc?(node)
  end

  test "holds_heredoc? is false for a plain multiline literal" do
    node = processed_source("PROBES = [\n  1,\n  2\n]\n").ast

    assert_not Helpers.holds_heredoc?(node)
  end

  test "class_name_of returns the name a class definition declares" do
    node = processed_source("class Foo::Bar\n  def baz; end\nend").ast

    assert_equal "Foo::Bar", Helpers.class_name_of(node)
  end

  test "class_name_of returns the constant a class builder assigns" do
    node = processed_source("Entry = Data.define(:sku)").ast

    assert_equal "Entry", Helpers.class_name_of(node)
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
