require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::MethodsTest < HelpersTestCase
  test "parameter_names_of returns names of positional and keyword arguments" do
    method = method_named("def foo(a, b = 1, c:, d: 2); end", :foo)

    assert_equal %w[a b c d], Helpers.parameter_names_of(method)
  end

  test "parameter_names_of ignores splat, double splat, and block arguments" do
    method = method_named("def foo(a, *rest, **opts, &block); end", :foo)

    assert_equal %w[a], Helpers.parameter_names_of(method)
  end

  test "parameter_node? returns true for parameter node types and false otherwise" do
    method = method_named("def foo(a, *rest); end", :foo)
    positional, splat = method.arguments.children

    assert Helpers.parameter_node?(positional)
    assert_not Helpers.parameter_node?(splat)
    assert_not Helpers.parameter_node?(nil)
  end

  test "inside_initialize? returns true for nodes inside def initialize" do
    ast = processed_source(<<~RUBY).ast
      class Foo
        def initialize
          @x = compute
        end
      end
    RUBY
    ivasgn = ast.each_node(:ivasgn).first

    assert Helpers.inside_initialize?(ivasgn)
  end

  test "inside_initialize? returns true for nodes inside def self.initialize" do
    ast = processed_source(<<~RUBY).ast
      class Foo
        def self.initialize
          @x = compute
        end
      end
    RUBY
    ivasgn = ast.each_node(:ivasgn).first

    assert Helpers.inside_initialize?(ivasgn)
  end

  test "inside_initialize? returns false for nodes outside initialize" do
    ast = processed_source(<<~RUBY).ast
      class Foo
        def setup
          @x = compute
        end
      end
    RUBY
    ivasgn = ast.each_node(:ivasgn).first

    assert_not Helpers.inside_initialize?(ivasgn)
  end

  test "single_send_private_non_predicate? returns true for a private method whose body is a single send" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        private
          def baz
            other
          end
      end
    RUBY

    assert Helpers.single_send_private_non_predicate?(method)
  end

  test "single_send_private_non_predicate? returns false for a public method" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        def baz
          other
        end
      end
    RUBY

    assert_not Helpers.single_send_private_non_predicate?(method)
  end

  test "single_send_private_non_predicate? returns false for a private predicate method" do
    method = method_named(<<~RUBY, :baz?)
      class Bar
        private
          def baz?
            other
          end
      end
    RUBY

    assert_not Helpers.single_send_private_non_predicate?(method)
  end
end
