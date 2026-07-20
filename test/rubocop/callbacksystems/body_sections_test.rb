require "test_helper"

class RuboCop::Callbacksystems::BodySectionsTest < ActiveSupport::TestCase
  test "public_method_nodes returns the methods before the private modifier" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end
        def baz; end

        private
          def internal; end
      end
    RUBY

    assert_equal %i[bar baz], sections.public_method_nodes.map(&:method_name)
  end

  test "each_child_with_visibility yields every child with its section" do
    sections = sections_of(<<~RUBY)
      class Foo
        def bar; end

        private
          def internal; end
      end
    RUBY

    assert_equal [ false, true, true ], sections.each_child_with_visibility.map { |_child, in_private| in_private }
  end

  test "each_child_with_visibility yields nothing for an empty body" do
    assert_empty RuboCop::Callbacksystems::BodySections.new(nil).each_child_with_visibility.to_a
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

    assert_equal %i[internal other], sections.private_method_nodes.map(&:method_name)
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

    assert_equal %w[Inner Other], sections.private_nested_classes.map { it.identifier.source }
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
      RuboCop::Callbacksystems::BodySections.new(RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast.body)
    end
end
