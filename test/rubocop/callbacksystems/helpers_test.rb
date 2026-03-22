require "test_helper"

class RuboCop::Callbacksystems::HelpersTest < ActiveSupport::TestCase
  test "first_statement returns single statement from simple body" do
    body = parse_method_body("def foo; bar; end")

    assert_equal :send, Helpers.first_statement(body).type
  end

  test "first_statement returns first of multiple statements" do
    body = parse_method_body("def foo; bar; baz; end")

    assert_equal :bar, Helpers.first_statement(body).method_name
  end

  test "first_statement unwraps rescue" do
    body = parse_method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement(body).method_name
  end

  test "first_statement unwraps ensure" do
    body = parse_method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement(body).method_name
  end

  test "last_statement returns single statement from simple body" do
    body = parse_method_body("def foo; bar; end")

    assert_equal :send, Helpers.last_statement(body).type
  end

  test "last_statement returns last of multiple statements" do
    body = parse_method_body("def foo; bar; baz; end")

    assert_equal :baz, Helpers.last_statement(body).method_name
  end

  test "last_statement unwraps rescue" do
    body = parse_method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement(body).method_name
  end

  test "last_statement unwraps ensure" do
    body = parse_method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement(body).method_name
  end

  test "assignment_count counts unique instance variable assignments" do
    body = parse_class_body(<<~RUBY)
      class Foo
        def initialize
          @a = 1
          @b = 2
          @a = 3
        end
      end
    RUBY

    assert_equal 2, Helpers.assignment_count(body, :ivasgn)
  end

  test "assignment_count counts unique local variable assignments" do
    body = parse_class_body(<<~RUBY)
      class Foo
        def initialize
          a = 1
          b = 2
          c = 3
        end
      end
    RUBY

    assert_equal 3, Helpers.assignment_count(body, :lvasgn)
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

  private
    Helpers = RuboCop::Callbacksystems::Helpers

    def parse(source)
      RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    end

    def parse_method_body(source)
      parse(source).ast.then { |ast| ast.def_type? ? ast.body : ast.each_node(:def).first.body }
    end

    def parse_class_body(source)
      parse(source).ast.body
    end

    def find_method(source, name)
      parse(source).ast.each_node(:def).find { |n| n.method_name == name }
    end
end
