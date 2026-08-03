require "test_helper"

class RuboCop::Callbacksystems::MethodRecursionTest < ActiveSupport::TestCase
  test "shifted_names returns a parameter the recursion hands on at another position" do
    assert_equal [ "node" ], recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, parent)
        children_of(node).each { walk(it, node) }
      end
    RUBY
  end

  test "shifted_names sees a shift through an explicit self receiver" do
    assert_equal [ "node" ], recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, parent)
        self.walk(child, node)
      end
    RUBY
  end

  test "shifted_names ignores a recursion that keeps every parameter in place" do
    assert_empty recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, depth)
        walk(node, depth) if node
      end
    RUBY
  end

  test "shifted_names ignores a call to a different method" do
    assert_empty recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, parent)
        descend(child, node)
      end
    RUBY
  end

  test "shifted_names ignores an argument that is not one of the parameters" do
    assert_empty recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, parent)
        walk(child, other)
      end
    RUBY
  end

  test "shifted_names ignores a call on another receiver" do
    assert_empty recursion_in(<<~RUBY, :walk).shifted_names
      def walk(node, parent)
        other.walk(child, node)
      end
    RUBY
  end

  test "shifted_names returns both parameters when a recursion swaps them" do
    assert_equal [ "left", "right" ], recursion_in(<<~RUBY, :swap).shifted_names.sort
      def swap(left, right)
        swap(right, left)
      end
    RUBY
  end

  private
    def recursion_in(source, method_name)
      node = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast.each_node(:def).find { it.method?(method_name) }
      RuboCop::Callbacksystems::MethodRecursion.new(node)
    end
end
