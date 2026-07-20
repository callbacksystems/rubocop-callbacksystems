require "test_helper"

class RuboCop::Callbacksystems::NodeVisibilityTest < ActiveSupport::TestCase
  test "public? returns true for a node before the private modifier" do
    assert visibility_of(<<~RUBY, :foo).public?
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY
  end

  test "public? returns false for a node after the private modifier" do
    assert_not visibility_of(<<~RUBY, :baz).public?
      class Bar
        private
          def baz; end
      end
    RUBY
  end

  test "level returns the modifier the node sits under" do
    assert_equal :protected, visibility_of(<<~RUBY, :baz).level
      class Bar
        protected
          def baz; end
      end
    RUBY
  end

  test "level returns public for a node outside any class" do
    assert_equal :public, visibility_of("def foo; end", :foo).level
  end

  test "enclosing_body returns the body holding the node" do
    body = visibility_of(<<~RUBY, :baz).enclosing_body
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY

    assert_predicate body, :begin_type?
  end

  test "enclosing_body returns nil for a body of a single statement" do
    assert_nil visibility_of(<<~RUBY, :foo).enclosing_body
      class Bar
        def foo; end
      end
    RUBY
  end

  test "enclosing_definition returns the class holding the node" do
    definition = visibility_of(<<~RUBY, :foo).enclosing_definition
      class Bar
        def foo; end
      end
    RUBY

    assert_equal "Bar", definition.identifier.source
  end

  test "enclosing_definition returns the singleton section holding the node" do
    definition = visibility_of(<<~RUBY, :foo).enclosing_definition
      class Bar
        class << self
          def foo; end
        end
      end
    RUBY

    assert_predicate definition, :sclass_type?
  end

  test "level_in reads the visibility from a body already at hand" do
    source = <<~RUBY
      class Bar
        def foo; end

        private
          def baz; end
      end
    RUBY
    visibility = visibility_of(source, :baz)

    assert_equal :private, visibility.level_in(visibility.enclosing_body)
  end

  test "private? returns true for a node after the private modifier" do
    assert visibility_of(<<~RUBY, :baz).private?
      class Bar
        private
          def baz; end
      end
    RUBY
  end

  test "private? returns false for a protected node" do
    assert_not visibility_of(<<~RUBY, :baz).private?
      class Bar
        protected
          def baz; end
      end
    RUBY
  end

  test "private_non_predicate? returns true for a private non-predicate method" do
    assert visibility_of(<<~RUBY, :baz).private_non_predicate?
      class Bar
        private
          def baz; end
      end
    RUBY
  end

  test "private_non_predicate? returns false for a private predicate method" do
    assert_not visibility_of(<<~RUBY, :baz?).private_non_predicate?
      class Bar
        private
          def baz?; end
      end
    RUBY
  end

  test "private_non_predicate? returns false for a public method" do
    assert_not visibility_of(<<~RUBY, :baz).private_non_predicate?
      class Bar
        def baz; end
      end
    RUBY
  end

  private
    def visibility_of(source, method_name)
      node = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast.each_node(:def).find { it.method?(method_name) }
      RuboCop::Callbacksystems::NodeVisibility.new(node)
    end
end
