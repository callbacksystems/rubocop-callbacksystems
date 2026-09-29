require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::ClassBodyTest < ActiveSupport::TestCase
  include SourceParsing

  test "public_method_nodes returns the methods before the private modifier" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end
        def baz; end

        private
          def internal; end
      end
    RUBY

    assert_equal %i[ bar baz ], sections.public_method_nodes.map(&:method_name)
  end

  test "public_method_nodes returns the methods below a public modifier reopening the section" do
    sections = sections_of(<<~RUBY)
      class Foo
        private
          def a; end

        public
          def b; end
      end
    RUBY

    assert_equal %i[ b ], sections.public_method_nodes.map(&:method_name)
  end

  test "public_children returns every statement up to and including the modifier closing the public section" do
    sections = sections_of(<<~RUBY)
      class Foo
        attr_reader :bar
        def baz; end

        private
          def internal; end
      end
    RUBY

    assert_equal [ "attr_reader :bar", "def baz; end", "private" ], sections.public_children.map(&:source)
  end

  test "each_child_with_visibility yields every child with the level of the last modifier above it" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end

        private
          def internal; end
      end
    RUBY

    assert_equal %i[ public public private ], sections.each_child_with_visibility.map { |_child, level| level }
  end

  test "each_child_with_visibility passes each child and level to a block" do
    sections = sections_of("class Foo\n  private\n    def bar; end\nend\n")
    yielded = []

    sections.each_child_with_visibility { |child, level| yielded << [ child.type, level ] }

    assert_equal [ [ :send, :public ], [ :def, :private ] ], yielded
  end

  test "each_child_with_visibility yields the lone statement of a body" do
    sections = sections_of("class Foo\n  def bar; end\nend\n")

    assert_equal [ :public ], sections.each_child_with_visibility.map { |_child, level| level }
  end

  test "each_child_with_visibility yields nothing for an empty body" do
    assert_empty RuboCop::Callbacksystems::ClassStructure::ClassBody.new(nil).each_child_with_visibility.to_a
  end

  test "private_method_nodes returns the methods after the private modifier" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end

        private
          def internal; end
          def other; end
      end
    RUBY

    assert_equal %i[ internal other ], sections.private_method_nodes.map(&:method_name)
  end

  test "private_method_nodes leaves out the methods below a public modifier reopening the section" do
    sections = sections_of(<<~RUBY)
      class Foo
        private
          def a; end

        public
          def b; end
      end
    RUBY

    assert_equal %i[ a ], sections.private_method_nodes.map(&:method_name)
  end

  test "private_nested_classes returns the classes after the private modifier" do
    sections = sections_of(<<~RUBY)
      class Foo
        class Public; end

        private
          class Inner; end
          class Other; end
      end
    RUBY

    assert_equal %w[ Inner Other ], sections.private_nested_classes.map { it.identifier.source }
  end

  test "in_private_section? returns true for a node below the private modifier" do
    body = processed_source(<<~RUBY).ast.body
      class Foo
        def bar; end

        private
          MEMBERS = [ :name ]
      end
    RUBY

    assert RuboCop::Callbacksystems::ClassStructure::ClassBody.new(body).in_private_section?(body.children.last)
  end

  test "in_private_section? returns false for a node above the private modifier" do
    body = processed_source(<<~RUBY).ast.body
      class Foo
        MEMBERS = [ :name ]

        private
          def bar; end
      end
    RUBY

    assert_not RuboCop::Callbacksystems::ClassStructure::ClassBody.new(body).in_private_section?(body.children.first)
  end

  test "in_private_section? returns false when there is no private section" do
    body = processed_source(<<~RUBY).ast.body
      class Foo
        MEMBERS = [ :name ]
        def bar; end
      end
    RUBY

    assert_not RuboCop::Callbacksystems::ClassStructure::ClassBody.new(body).in_private_section?(body.children.first)
  end

  test "private_modifier returns the modifier that opens the private section" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end

        private
          def internal; end
      end
    RUBY

    assert_equal :private, sections.private_modifier.method_name
  end

  test "private_modifier returns nil when there is no private section" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end
      end
    RUBY

    assert_nil sections.private_modifier
  end

  private
    def sections_of(source)
      RuboCop::Callbacksystems::ClassStructure::ClassBody.new(processed_source(source).ast.body)
    end
end
