require "test_helper"

class RuboCop::Callbacksystems::Helpers::NamesTest < HelpersTestCase
  test "literal_name_of returns the string a symbol or string literal names" do
    assert_equal "users", Helpers.literal_name_of(processed_source(":users").ast)
    assert_equal "users", Helpers.literal_name_of(processed_source("\"users\"").ast)
  end

  test "literal_name_of returns the source of any other node" do
    assert_equal "Admin::Users", Helpers.literal_name_of(processed_source("Admin::Users").ast)
  end

  test "declared_name_of returns the name a constant or variable assignment declares" do
    assert_equal :LIMIT, Helpers.declared_name_of(processed_source("LIMIT = 1").ast)
    assert_equal :limit, Helpers.declared_name_of(processed_source("limit = 1").ast)
  end

  test "declared_name_of returns the name a class or module declares" do
    assert_equal :Item, Helpers.declared_name_of(processed_source("class Item; end").ast)
    assert_equal :Items, Helpers.declared_name_of(processed_source("module Items; end").ast)
  end

  test "declared_name_of returns nil for a statement that declares nothing" do
    assert_nil Helpers.declared_name_of(processed_source("validate :name").ast)
  end

  test "name_arguments_of returns the symbol and string arguments a macro names" do
    ast = processed_source('private_constant :FOO, "BAR", SOMETHING').ast

    assert_equal [ ":FOO", "\"BAR\"" ], Helpers.name_arguments_of(ast).map(&:source)
  end

  test "name_arguments_of returns nothing when the call names no arguments" do
    ast = processed_source("private").ast

    assert_empty Helpers.name_arguments_of(ast)
  end

  test "class_name_of returns the name a class definition declares" do
    node = processed_source("class Foo::Bar\n  def baz; end\nend").ast

    assert_equal "Foo::Bar", Helpers.class_name_of(node)
  end

  test "class_name_of returns the constant a class builder assigns" do
    node = processed_source("Entry = Data.define(:sku)").ast

    assert_equal "Entry", Helpers.class_name_of(node)
  end

  test "name_without_sigil strips the @ of an instance variable name" do
    assert_equal "order", Helpers.name_without_sigil(:@order)
  end

  test "name_without_sigil strips class and global variable sigils" do
    assert_equal "order", Helpers.name_without_sigil(:@@order)
    assert_equal "order", Helpers.name_without_sigil(:$order)
  end

  test "name_without_sigil leaves a plain name alone" do
    assert_equal "order", Helpers.name_without_sigil(:order)
  end

  test "constant_name_of returns simple constant name" do
    node = processed_source("Foo").ast

    assert_equal "Foo", Helpers.constant_name_of(node)
  end

  test "constant_name_of returns nil for a node that names no constant" do
    assert_nil Helpers.constant_name_of(processed_source("foo").ast)
  end

  test "constant_name_of returns namespaced constant" do
    node = processed_source("Foo::Bar::Baz").ast

    assert_equal "Foo::Bar::Baz", Helpers.constant_name_of(node)
  end

  test "constant_name_of preserves an absolute constant root" do
    node = processed_source("::Foo::Bar").ast

    assert_equal "::Foo::Bar", Helpers.constant_name_of(node)
  end

  test "constant_name_of rejects a constant reached through an expression" do
    node = processed_source("namespace::Bar").ast

    assert_nil Helpers.constant_name_of(node)
  end

  test "constant_name_of handles a deeply nested constant without recursive descent" do
    name = (1..2_000).map { "C#{it}" }.join("::")

    assert_equal name, Helpers.constant_name_of(processed_source(name).ast)
  end

  test "constant_name_of returns nil for nil input" do
    assert_nil Helpers.constant_name_of(nil)
  end
end
