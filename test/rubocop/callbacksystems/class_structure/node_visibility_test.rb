require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::NodeVisibilityTest < ActiveSupport::TestCase
  include SourceParsing

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

  test "level reads a private section inside a constructor block" do
    assert_equal :private, visibility_of(<<~RUBY, :calculate).level
      class Outer
        Handler = Class.new do
          private
            def calculate; end
        end
      end
    RUBY
  end

  test "level does not inherit an enclosing private section through a constructor block" do
    assert_equal :public, visibility_of(<<~RUBY, :calculate).level
      class Outer
        private

        Handler = Class.new do
          def calculate; end
        end
      end
    RUBY
  end

  test "level returns the modifier wrapping the node" do
    assert_equal :private, visibility_of(<<~RUBY, :baz).level
      class Bar
        def foo; end

        private def baz; end
      end
    RUBY
  end

  test "level returns the modifier wrapping the only node of a body" do
    assert_equal :protected, visibility_of(<<~RUBY, :baz).level
      class Bar
        protected def baz; end
      end
    RUBY
  end

  test "level returns public for a node below a public modifier reopening the section" do
    assert_equal :public, visibility_of(<<~RUBY, :b).level
      class Bar
        private
          def a; end

        public
          def b; end
      end
    RUBY
  end

  test "level leaves the section alone after a wrapped node" do
    assert_equal :public, visibility_of(<<~RUBY, :qux).level
      class Bar
        private def baz; end

        def qux; end
      end
    RUBY
  end

  test "level reads a private modifier naming an earlier method" do
    assert_equal :private, visibility_of(<<~RUBY, :foo).level
      class Bar
        def foo; end
        private :foo
      end
    RUBY
  end

  test "level reads the last modifier naming an earlier method" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        def foo; end
        private :foo
        public :foo
      end
    RUBY
  end

  test "level leaves a method alone when a modifier names another method" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        def foo; end
        def hidden; end
        private :hidden
      end
    RUBY
  end

  test "level keeps a singleton method public below an instance private section" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        private
          def self.foo; end
      end
    RUBY
  end

  test "level reads private_class_method naming an earlier singleton method" do
    assert_equal :private, visibility_of(<<~RUBY, :foo).level
      class Bar
        def self.foo; end
        private_class_method :foo
      end
    RUBY
  end

  test "level reads private_class_method wrapping a singleton method" do
    assert_equal :private, visibility_of(<<~RUBY, :foo).level
      class Bar
        private_class_method def self.foo; end
      end
    RUBY
  end

  test "level reads public_class_method wrapping a singleton method" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        public_class_method def self.foo; end
      end
    RUBY
  end

  test "level does not let an instance modifier wrap a singleton definition" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        private def self.foo; end
      end
    RUBY
  end

  test "level does not let a class method modifier wrap an instance definition" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        private_class_method def foo; end
      end
    RUBY
  end

  test "level reads private_class_method naming a method from a singleton section" do
    assert_equal :private, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          def foo; end
        end

        private_class_method :foo
      end
    RUBY
  end

  test "level reads a later public_class_method for a private method from a singleton section" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          private
            def foo; end
        end

        public_class_method :foo
      end
    RUBY
  end

  test "level does not apply an outer named modifier through a singleton class for another expression" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << Other
          def foo; end
        end

        private_class_method :foo
      end
    RUBY
  end

  test "level does not apply an outer named modifier through a nested class in a singleton section" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          class Inner
            def self.foo; end
          end
        end

        private_class_method :foo
      end
    RUBY
  end

  test "level applies a named modifier from the immediate owner of a nested singleton section" do
    assert_equal :private, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          class << self
            def foo; end
          end

          private_class_method :foo
        end
      end
    RUBY
  end

  test "level does not apply a named modifier past the immediate owner of a nested singleton section" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          class << self
            def foo; end
          end
        end

        private_class_method :foo
      end
    RUBY
  end

  test "level reads a class method modifier from its constructor block owner" do
    assert_equal :private, visibility_of(<<~RUBY, :call).level
      class Outer
        Handler = Class.new do
          class << self
            def call; end
          end

          private_class_method :call
        end
      end
    RUBY
  end

  test "level does not apply an outer class method modifier through a constructor block" do
    assert_equal :public, visibility_of(<<~RUBY, :call).level
      class Outer
        Handler = Class.new do
          class << self
            def call; end
          end
        end

        private_class_method :call
      end
    RUBY
  end

  test "level does not apply an outer instance modifier to a method from a singleton section" do
    assert_equal :public, visibility_of(<<~RUBY, :foo).level
      class Bar
        class << self
          def foo; end
        end

        private :foo
      end
    RUBY
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

  test "level_in reads the modifiers before the statement holding the node, not the whole body" do
    source = <<~RUBY
      class Plan
        LIMIT = 1
        REGISTRY = { pages: LIMIT }

        private
          def pages; end
      end
    RUBY
    read = processed_source(source).ast.each_descendant(:const).find { it.short_name == :LIMIT }
    visibility = RuboCop::Callbacksystems::ClassStructure::NodeVisibility.new(read)

    assert_equal :public, visibility.level_in(visibility.enclosing_body)
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

  test "protected? returns true for a node after the protected modifier" do
    assert visibility_of(<<~RUBY, :baz).protected?
      class Bar
        protected
          def baz; end
      end
    RUBY
  end

  test "protected? returns false for a private node" do
    assert_not visibility_of(<<~RUBY, :baz).protected?
      class Bar
        private
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
      definitions = processed_source(source).ast.each_node(:def, :defs)
      RuboCop::Callbacksystems::ClassStructure::NodeVisibility.new(definitions.find { it.method?(method_name) })
    end
end
