require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::BodiesTest < HelpersTestCase
  test "assignment_count counts unique instance variable assignments" do
    body = class_body(<<~RUBY)
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
    body = class_body(<<~RUBY)
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

  test "assignment_count returns 0 for nil body" do
    assert_equal 0, Helpers.assignment_count(nil, :ivasgn)
  end

  test "statements_in unwraps begin into its children" do
    body = method_body(<<~RUBY)
      def foo
        a
        b
        c
      end
    RUBY

    assert_equal %i[a b c], Helpers.statements_in(body).map(&:method_name)
  end

  test "statements_in wraps a single statement in an array" do
    body = method_body("def foo; bar; end")

    assert_equal [ :bar ], Helpers.statements_in(body).map(&:method_name)
  end

  test "statements_in returns empty for nil body" do
    assert_empty Helpers.statements_in(nil)
  end

  test "receiverless_method_names_in collects bare sends from the body" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz(1)
        self.qux
        SomeConst.zap
      end
    RUBY

    assert_equal [ :bar, :baz ], Helpers.receiverless_method_names_in(body)
  end

  test "receiverless_method_names_in traverses nested expressions" do
    body = method_body(<<~RUBY)
      def foo
        if condition?
          process
        end
      end
    RUBY

    assert_equal [ :condition?, :process ], Helpers.receiverless_method_names_in(body)
  end

  test "receiverless_method_names_in returns empty for nil body" do
    assert_empty Helpers.receiverless_method_names_in(nil)
  end

  test "first_statement_in returns single statement from simple body" do
    body = method_body("def foo; bar; end")

    assert_equal :send, Helpers.first_statement_in(body).type
  end

  test "first_statement_in returns first of multiple statements" do
    body = method_body("def foo; bar; baz; end")

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in unwraps rescue" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in unwraps ensure" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in returns nil for nil body" do
    assert_nil Helpers.first_statement_in(nil)
  end

  test "last_statement_in returns single statement from simple body" do
    body = method_body("def foo; bar; end")

    assert_equal :send, Helpers.last_statement_in(body).type
  end

  test "last_statement_in returns last of multiple statements" do
    body = method_body("def foo; bar; baz; end")

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in unwraps rescue" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in unwraps ensure" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in returns nil for nil body" do
    assert_nil Helpers.last_statement_in(nil)
  end

  test "direct_method_nodes_in returns method defs at the top of a class body" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end
        def baz; end
      end
    RUBY

    assert_equal [ :bar, :baz ], Helpers.direct_method_nodes_in(body).map(&:method_name)
  end

  test "direct_method_nodes_in ignores defs inside nested classes" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end

        class Inner
          def baz; end
        end
      end
    RUBY

    assert_equal [ :bar ], Helpers.direct_method_nodes_in(body).map(&:method_name)
  end

  test "direct_method_nodes_in returns empty for nil body" do
    assert_empty Helpers.direct_method_nodes_in(nil)
  end
end
