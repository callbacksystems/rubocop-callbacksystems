require "test_helper"

class RuboCop::Callbacksystems::Helpers::VisibilityTest < HelpersTestCase
  test "public_method? returns true for methods before private" do
    method = method_named(<<~RUBY, :foo)
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert Helpers.public_method?(method)
  end

  test "public_method? returns false for methods after private" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        private
          def baz; end
      end
    RUBY

    assert_not Helpers.public_method?(method)
  end

  test "visibility_of returns public for methods before private" do
    method = method_named(<<~RUBY, :foo)
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert_equal :public, Helpers.visibility_of(method)
  end

  test "visibility_of returns private for methods after private" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert_equal :private, Helpers.visibility_of(method)
  end

  test "visibility_of returns protected for methods after protected" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        protected
          def baz; end
      end
    RUBY

    assert_equal :protected, Helpers.visibility_of(method)
  end

  test "visibility_at returns public when no modifier precedes method" do
    source = <<~RUBY
      class Foo
        def bar; end
        def baz; end
      end
    RUBY
    ast = processed_source(source).ast
    body = ast.body
    method = body.children.first

    assert_equal :public, Helpers.visibility_at(method, body)
  end

  test "visibility_at returns private after private modifier" do
    source = <<~RUBY
      class Foo
        private
          def bar; end
      end
    RUBY
    ast = processed_source(source).ast
    body = ast.body
    method = body.children.last

    assert_equal :private, Helpers.visibility_at(method, body)
  end

  test "enclosing_body_for returns class body" do
    method = method_named(<<~RUBY, :foo)
      class Bar
        def foo; end
        def baz; end
      end
    RUBY

    assert_equal :begin, Helpers.enclosing_body_for(method).type
  end

  test "enclosing_body_for returns nil for method outside class" do
    method = processed_source("def foo; end").ast

    assert_nil Helpers.enclosing_body_for(method)
  end

  test "enclosing_definition_of returns the class holding the node" do
    method = method_named(<<~RUBY, :foo)
      class Bar
        def foo; end
      end
    RUBY

    assert_equal "Bar", Helpers.enclosing_definition_of(method).identifier.source
  end

  test "enclosing_definition_of returns nil at the top level" do
    method = method_named("def foo; end", :foo)

    assert_nil Helpers.enclosing_definition_of(method)
  end

  test "private_modifier_in returns the private modifier of the body" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end

        private
          def baz; end
      end
    RUBY

    assert_equal :private, Helpers.private_modifier_in(body).method_name
  end

  test "private_modifier_in returns nil when the body has no private section" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end

        protected
          def baz; end
      end
    RUBY

    assert_nil Helpers.private_modifier_in(body)
  end

  test "in_private_section? tells which side of the modifier a node sits on" do
    body = class_body(<<~RUBY)
      class Foo
        MEMBERS = [ :name ]

        private
          ROUTES = [ :show ]
      end
    RUBY

    assert Helpers.in_private_section?(body.children.last, body)
    assert_not Helpers.in_private_section?(body.children.first, body)
  end

  test "visibility_applied_to returns the modifier wrapping the definition" do
    source = <<~RUBY
      class Bar
        private def baz; end
      end
    RUBY

    assert_equal :private, Helpers.visibility_applied_to(class_body(source), method_named(source, :baz))
  end

  test "visibility_applied_to returns nil for a modifier opening a section" do
    source = <<~RUBY
      class Bar
        private
          def baz; end
      end
    RUBY

    assert_nil Helpers.visibility_applied_to(class_body(source).children.first, method_named(source, :baz))
  end

  test "visibility_applied_to returns nil for a macro wrapping the definition" do
    source = <<~RUBY
      class Bar
        memoize def baz; end
      end
    RUBY

    assert_nil Helpers.visibility_applied_to(class_body(source), method_named(source, :baz))
  end

  test "visibility_applied_to recognizes a public_class_method wrapper" do
    source = "class Bar\n  public_class_method def self.build; end\nend\n"
    wrapper = class_body(source)

    assert_equal :public, Helpers.visibility_applied_to(wrapper, wrapper.first_argument)
  end

  test "visibility_applied_to rejects public_class_method around an instance definition" do
    source = "class Bar\n  public_class_method def build; end\nend\n"
    wrapper = class_body(source)

    assert_nil Helpers.visibility_applied_to(wrapper, method_named(source, :build))
  end

  test "private_method? returns true for methods after private" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        private
          def baz; end
      end
    RUBY

    assert Helpers.private_method?(method)
  end

  test "private_method? returns false for protected methods" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        protected
          def baz; end
      end
    RUBY

    assert_not Helpers.private_method?(method)
  end

  test "protected_method? returns true for methods after protected" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        protected
          def baz; end
      end
    RUBY

    assert Helpers.protected_method?(method)
  end

  test "protected_method? returns false for private methods" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        private
          def baz; end
      end
    RUBY

    assert_not Helpers.protected_method?(method)
  end

  test "private_non_predicate? returns true for private non-predicate method" do
    method = method_named(<<~RUBY, :process)
      class Foo
        private
          def process; end
      end
    RUBY

    assert Helpers.private_non_predicate?(method)
  end

  test "private_non_predicate? returns false for predicate method" do
    method = method_named(<<~RUBY, :valid?)
      class Foo
        private
          def valid?; end
      end
    RUBY

    assert_not Helpers.private_non_predicate?(method)
  end

  test "private_non_predicate? returns false for public method" do
    method = method_named(<<~RUBY, :process)
      class Foo
        def process; end
      end
    RUBY

    assert_not Helpers.private_non_predicate?(method)
  end

  test "private_nested_class? returns true for class in private section" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        private
          class Inner; end
      end
    RUBY
    inner = ast.body.children.last

    assert Helpers.private_nested_class?(inner)
  end

  test "private_nested_class? returns false for top-level class" do
    ast = processed_source(<<~RUBY).ast
      class Outer
      end
    RUBY

    assert_not Helpers.private_nested_class?(ast)
  end

  test "private_nested_class? returns false for public nested class" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        class Inner; end
      end
    RUBY
    inner = ast.body

    assert_not Helpers.private_nested_class?(inner)
  end

  test "enclosing_class_or_module_of returns the surrounding class" do
    method = method_named(<<~RUBY, :foo)
      class Bar
        def foo; end
      end
    RUBY

    assert_equal :Bar, Helpers.enclosing_class_or_module_of(method).identifier.short_name
  end

  test "enclosing_class_or_module_of returns the surrounding module" do
    method = method_named(<<~RUBY, :foo)
      module Bar
        def foo; end
      end
    RUBY

    assert_equal :Bar, Helpers.enclosing_class_or_module_of(method).identifier.short_name
  end

  test "enclosing_class_or_module_of returns nil at the top level" do
    method = processed_source("def foo; end").ast

    assert_nil Helpers.enclosing_class_or_module_of(method)
  end

  test "private_nested_classes_in returns classes after private" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        def foo; end

        private
          class Inner; end
          class Other; end
      end
    RUBY

    classes = Helpers.private_nested_classes_in(ast)

    assert_equal 2, classes.size
    assert_equal :Inner, classes.first.identifier.short_name
  end

  test "private_nested_classes_in returns empty for no private classes" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        def foo; end
      end
    RUBY

    assert_empty Helpers.private_nested_classes_in(ast)
  end

  test "public_methods_in returns methods before private" do
    ast = processed_source(<<~RUBY).ast
      class Foo
        def bar; end
        def baz; end

        private
          def qux; end
      end
    RUBY

    methods = Helpers.public_methods_in(ast)

    assert_equal [ :bar, :baz ], methods.map(&:method_name)
  end

  test "private_methods_in returns methods after private" do
    ast = processed_source(<<~RUBY).ast
      class Foo
        def bar; end

        private
          def baz; end
          def qux; end
      end
    RUBY

    methods = Helpers.private_methods_in(ast)

    assert_equal [ :baz, :qux ], methods.map(&:method_name)
  end

  test "enclosing_method_of finds the method a node sits in" do
    node = processed_source("def total\n  value\nend").ast.body

    assert_equal :total, Helpers.enclosing_method_of(node).method_name
  end

  test "enclosing_method_of finds a singleton method too" do
    node = processed_source("def self.total\n  value\nend").ast.body

    assert_equal :total, Helpers.enclosing_method_of(node).method_name
  end

  test "enclosing_scope_of finds the block a node sits in before the method around it" do
    node = processed_source("def total\n  items.each { value }\nend").ast.each_node(:send).find { it.method?(:value) }

    assert Helpers.enclosing_scope_of(node).block_type?
  end

  test "enclosing_scope_of finds the method when no block wraps the node" do
    node = processed_source("def total\n  value\nend").ast.body

    assert_equal :total, Helpers.enclosing_scope_of(node).method_name
  end

  test "enclosing_scope_of returns nil at the top level" do
    assert_nil Helpers.enclosing_scope_of(processed_source("value").ast)
  end

  test "sibling_method_nodes_of lists the methods defined beside a node's method" do
    node = method_named("class A\n  def one; end\n  def two; end\nend", :one)

    assert_equal %i[ one two ], Helpers.sibling_method_nodes_of(node).map(&:method_name)
  end

  test "sibling_method_nodes_of is empty outside a class or module" do
    assert_empty Helpers.sibling_method_nodes_of(processed_source("def one; end").ast)
  end

  test "leaves_public_section? is true for a bare private or protected" do
    assert Helpers.leaves_public_section?(processed_source("private").ast)
    assert Helpers.leaves_public_section?(processed_source("protected").ast)
  end

  test "leaves_public_section? is false for public and for other statements" do
    assert_not Helpers.leaves_public_section?(processed_source("public").ast)
    assert_not Helpers.leaves_public_section?(processed_source("foo").ast)
  end

  test "visibility_modifier_of returns the modifier symbol" do
    body = class_body(<<~RUBY)
      class Foo
        private
      end
    RUBY

    assert_equal :private, Helpers.visibility_modifier_of(body)
  end

  test "visibility_modifier_of returns nil for non-modifier sends" do
    body = class_body(<<~RUBY)
      class Foo
        attr_reader :name
      end
    RUBY

    assert_nil Helpers.visibility_modifier_of(body)
  end

  test "visibility_modifier_of returns nil for a bare call that names no level" do
    body = class_body(<<~RUBY)
      class Foo
        freeze
      end
    RUBY

    assert_nil Helpers.visibility_modifier_of(body)
  end

  test "private_constant_names_of lists the constants a private_constant hides as symbols" do
    assert_equal %i[ A B ], Helpers.private_constant_names_of(processed_source("private_constant :A, \"B\"").ast)
  end

  test "private_constant_names_of is empty for any other statement" do
    assert_empty Helpers.private_constant_names_of(processed_source("private :a").ast)
  end

  test "names_marked_by lists the names a marker macro is given" do
    node = processed_source("private_constant :A, :B").ast

    assert_equal %i[ A B ], Helpers.names_marked_by(node, macro: :private_constant).map(&:value)
  end

  test "names_marked_by is empty for another macro or a receiver" do
    assert_empty Helpers.names_marked_by(processed_source("private :a").ast, macro: :private_constant)
    assert_empty Helpers.names_marked_by(processed_source("self.private_constant :A").ast, macro: :private_constant)
  end
end
