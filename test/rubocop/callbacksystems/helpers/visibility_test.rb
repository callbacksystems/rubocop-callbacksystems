require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::VisibilityTest < HelpersTestCase
  test "method_visibility returns public for methods before private" do
    method = find_method(<<~RUBY, :foo)
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert_equal :public, Helpers.method_visibility(method)
  end

  test "method_visibility returns private for methods after private" do
    method = find_method(<<~RUBY, :baz)
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert_equal :private, Helpers.method_visibility(method)
  end

  test "method_visibility returns protected for methods after protected" do
    method = find_method(<<~RUBY, :baz)
      class Bar
        protected
          def baz; end
      end
    RUBY

    assert_equal :protected, Helpers.method_visibility(method)
  end

  test "visibility_modifier returns the modifier symbol" do
    body = parse_class_body(<<~RUBY)
      class Foo
        private
      end
    RUBY

    assert_equal :private, Helpers.visibility_modifier(body)
  end

  test "visibility_modifier returns nil for non-modifier sends" do
    body = parse_class_body(<<~RUBY)
      class Foo
        attr_reader :name
      end
    RUBY

    assert_nil Helpers.visibility_modifier(body)
  end

  test "enclosing_body_for returns class body" do
    method = find_method(<<~RUBY, :foo)
      class Bar
        def foo; end
        def baz; end
      end
    RUBY

    assert_equal :begin, Helpers.enclosing_body_for(method).type
  end

  test "enclosing_body_for returns nil for method outside class" do
    method = parse("def foo; end").ast

    assert_nil Helpers.enclosing_body_for(method)
  end

  test "visibility_at returns public when no modifier precedes method" do
    source = <<~RUBY
      class Foo
        def bar; end
        def baz; end
      end
    RUBY
    ast = parse(source).ast
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
    ast = parse(source).ast
    body = ast.body
    method = body.children.last

    assert_equal :private, Helpers.visibility_at(method, body)
  end

  test "each_child_with_visibility yields children with private status" do
    ast = parse(<<~RUBY).ast
      class Foo
        def bar; end

        private
          def baz; end
      end
    RUBY

    results = Helpers.each_child_with_visibility(ast).map { |child, in_private| [ child.type, in_private ] }

    assert_equal [ [ :def, false ], [ :send, true ], [ :def, true ] ], results
  end

  test "private_nested_classes returns classes after private" do
    ast = parse(<<~RUBY).ast
      class Outer
        def foo; end

        private
          class Inner; end
          class Other; end
      end
    RUBY

    classes = Helpers.private_nested_classes(ast)

    assert_equal 2, classes.size
    assert_equal :Inner, classes.first.identifier.short_name
  end

  test "private_nested_classes returns empty for no private classes" do
    ast = parse(<<~RUBY).ast
      class Outer
        def foo; end
      end
    RUBY

    assert_empty Helpers.private_nested_classes(ast)
  end

  test "public_methods_in returns methods before private" do
    ast = parse(<<~RUBY).ast
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
    ast = parse(<<~RUBY).ast
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

  test "direct_child_of_class? returns true for direct method" do
    source = <<~RUBY
      class Outer
        def foo; end
      end
    RUBY
    ast = parse(source).ast
    method = ast.body

    assert Helpers.direct_child_of_class?(method, ast)
  end

  test "direct_child_of_class? returns false for nested method" do
    source = <<~RUBY
      class Outer
        class Inner
          def foo; end
        end
      end
    RUBY
    ast = parse(source).ast
    inner_class = ast.body
    method = inner_class.body

    assert_not Helpers.direct_child_of_class?(method, ast)
  end

  test "private_non_predicate? returns true for private non-predicate method" do
    method = find_method(<<~RUBY, :process)
      class Foo
        private
          def process; end
      end
    RUBY

    assert Helpers.private_non_predicate?(method)
  end

  test "private_non_predicate? returns false for predicate method" do
    method = find_method(<<~RUBY, :valid?)
      class Foo
        private
          def valid?; end
      end
    RUBY

    assert_not Helpers.private_non_predicate?(method)
  end

  test "private_non_predicate? returns false for public method" do
    method = find_method(<<~RUBY, :process)
      class Foo
        def process; end
      end
    RUBY

    assert_not Helpers.private_non_predicate?(method)
  end
end
