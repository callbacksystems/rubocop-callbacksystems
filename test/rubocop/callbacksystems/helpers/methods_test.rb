require "test_helper"

class RuboCop::Callbacksystems::Helpers::MethodsTest < HelpersTestCase
  test "builder_method? tells a call that builds or finds a record from any other call" do
    sources = [ "User.new(name: 1)", "User.find_by(name: 1)", "user.save" ]
    creation, lookup, other = sources.map { processed_source(it).ast }

    assert Helpers.builder_method?(creation)
    assert Helpers.builder_method?(lookup)
    assert_not Helpers.builder_method?(other)
  end

  test "parameter_names_of returns names of positional and keyword arguments" do
    method = method_named("def foo(a, b = 1, c:, d: 2); end", :foo)

    assert_equal %w[ a b c d ], Helpers.parameter_names_of(method)
  end

  test "parameter_names_of ignores splat, double splat, and block arguments" do
    method = method_named("def foo(a, *rest, **opts, &block); end", :foo)

    assert_equal %w[ a ], Helpers.parameter_names_of(method)
  end

  test "parameter_nodes_of lists the parameters a method declares" do
    method = processed_source("def total(count, rate = 1, *rest, unit:, scope: nil, **options, &block); end").ast

    assert_equal %i[ arg optarg kwarg kwoptarg ], Helpers.parameter_nodes_of(method).map(&:type)
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

  test "direct_method_definition? distinguishes named-owner methods from definitions below runtime boundaries" do
    methods = processed_source(<<~RUBY).ast.each_node(:def).to_a
      class Report
        def direct; end

        Wrapper = Class.new do
          def wrapped; end
        end

        def outer
          def nested; end
        end
      end
    RUBY

    assert Helpers.direct_method_definition?(methods.first)
    assert_not Helpers.direct_method_definition?(methods.second)
    assert_not Helpers.direct_method_definition?(methods.last)
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

  test "single_send_private_non_predicate? returns false for a method with an empty body" do
    method = method_named(<<~RUBY, :baz)
      class Bar
        private
          def baz
          end
      end
    RUBY

    assert_not Helpers.single_send_private_non_predicate?(method)
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

  test "single_send_private_non_predicate? returns false for a protected method" do
    processed = processed_source <<~RUBY
      class Foo
        protected
          def bar
            baz
          end
      end
    RUBY
    method = processed.ast.each_node(:def).first

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
