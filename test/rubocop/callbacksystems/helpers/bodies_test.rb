require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::BodiesTest < HelpersTestCase
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

  test "first_statement returns nil for nil body" do
    assert_nil Helpers.first_statement(nil)
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

  test "last_statement returns nil for nil body" do
    assert_nil Helpers.last_statement(nil)
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

  test "assignment_count returns 0 for nil body" do
    assert_equal 0, Helpers.assignment_count(nil, :ivasgn)
  end

  test "direct_method_nodes returns method defs at the top of a class body" do
    body = parse_class_body(<<~RUBY)
      class Foo
        def bar; end
        def baz; end
      end
    RUBY

    assert_equal [ :bar, :baz ], Helpers.direct_method_nodes(body).map(&:method_name)
  end

  test "direct_method_nodes ignores defs inside nested classes" do
    body = parse_class_body(<<~RUBY)
      class Foo
        def bar; end

        class Inner
          def baz; end
        end
      end
    RUBY

    assert_equal [ :bar ], Helpers.direct_method_nodes(body).map(&:method_name)
  end

  test "direct_method_nodes returns empty for nil body" do
    assert_empty Helpers.direct_method_nodes(nil)
  end
end
