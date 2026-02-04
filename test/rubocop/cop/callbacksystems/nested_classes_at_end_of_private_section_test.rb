require "test_helper"

class NestedClassesAtEndOfPrivateSectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NestedClassesAtEndOfPrivateSection

  test "registers offense for method after nested class" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          class Bar
          end

          def helper_method
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "helper_method"
  end

  test "no offense when nested classes are at the end" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def helper_method
          end

          class Bar
          end
      end
    RUBY
  end

  test "no offense when no nested classes" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def helper_one
          end

          def helper_two
          end
      end
    RUBY
  end

  test "no offense in public section" do
    assert_no_offense <<~RUBY
      class Foo
        class Bar
        end

        def helper_method
        end
      end
    RUBY
  end

  test "registers offense for multiple methods after class" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          class Bar
          end

          def helper_one
          end

          def helper_two
          end
      end
    RUBY

    assert_equal 2, offenses.count
  end

  test "works with modules" do
    offenses = assert_offense <<~RUBY
      module Foo
        private
          class Bar
          end

          def helper
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
