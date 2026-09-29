require "test_helper"

class RuboCop::Callbacksystems::Helpers::RecursionTest < HelpersTestCase
  test "recursion_subject_names_in collects names passed both directly and as a derived receiver" do
    ast = processed_source(<<~RUBY).ast
      def walk(node)
        walk(node.child, node)
      end
    RUBY

    assert_equal Set["node"], Helpers.recursion_subject_names_in(ast)
  end

  test "recursion_subject_names_in returns an empty set when no recursion subject is present" do
    ast = processed_source(<<~RUBY).ast
      def walk(node, other)
        walk(node.child, other)
      end
    RUBY

    assert_empty Helpers.recursion_subject_names_in(ast)
  end

  test "recursion_subject_names_in reads a call handed to it directly" do
    call = send_node("walk(node.child, node)")

    assert_equal Set["node"], Helpers.recursion_subject_names_in(call)
  end

  test "recursion_subject_names_in returns an empty set for no node" do
    assert_empty Helpers.recursion_subject_names_in(nil)
  end

  test "recursion_subject_names_in gathers subjects from every nested call" do
    ast = processed_source(<<~RUBY).ast
      def walk(node, scope)
        descend(node.child, node)
        widen(scope.parent, scope)
      end
    RUBY

    assert_equal Set["node", "scope"], Helpers.recursion_subject_names_in(ast)
  end

  test "recursion_subject_names_in reads safely navigated derived values" do
    ast = processed_source(<<~RUBY).ast
      def walk(node)
        walk(node&.child, node)
      end
    RUBY

    assert_equal Set["node"], Helpers.recursion_subject_names_in(ast)
  end

  test "recursion_subjects_in returns names passed both directly and as a derived receiver" do
    call = send_node("walk(node.child, node)")

    assert_equal [ "node" ], Helpers.recursion_subjects_in(call)
  end

  test "recursion_subjects_in returns empty when a direct argument is not also a derived receiver" do
    call = send_node("walk(node.child, other)")

    assert_empty Helpers.recursion_subjects_in(call)
  end

  test "derived_receiver_names_in returns receivers of send arguments that are local variables" do
    call = send_node("walk(node.child, value)")

    assert_equal Set["node"], Helpers.derived_receiver_names_in(call)
  end

  test "derived_receiver_names_in ignores arguments that are not sends" do
    call = send_node("walk(node, other)")

    assert_empty Helpers.derived_receiver_names_in(call)
  end

  test "derived_receiver_names_in reads safely navigated arguments" do
    call = send_node("walk(node&.child, value)")

    assert_equal Set["node"], Helpers.derived_receiver_names_in(call)
  end

  test "local_variable_name_of returns the name of a local variable node" do
    lvar = send_node("walk(node)").first_argument

    assert_equal "node", Helpers.local_variable_name_of(lvar)
  end

  test "local_variable_name_of returns nil for a non-local-variable node" do
    argument = send_node("walk(Const)").first_argument

    assert_nil Helpers.local_variable_name_of(argument)
  end

  test "local_variable_name_of returns nil for a nil argument" do
    assert_nil Helpers.local_variable_name_of(nil)
  end

  test "direct_argument_names_in returns names of arguments that are local variables" do
    call = send_node("walk(node, child.value, other)")

    assert_equal %w[ node other ], Helpers.direct_argument_names_in(call)
  end

  test "direct_argument_names_in returns empty when no argument is a local variable" do
    call = send_node("walk(Const, child.value)")

    assert_empty Helpers.direct_argument_names_in(call)
  end

  private
    def send_node(source)
      ast = processed_source(<<~RUBY).ast
        def walk(node, other, child, value, scope)
          #{source}
        end
      RUBY
      ast.each_node(:send).find { it.method?(:walk) && it.arguments.any? }
    end
end
