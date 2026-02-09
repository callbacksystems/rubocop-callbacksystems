require "test_helper"

class UnusedPrivateMethodInNestedClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::UnusedPrivateMethodInNestedClass

  test "registers offense for unused private method in private nested class" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run
              helper
            end

            private
              def helper; end
              def unused; end
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "unused"
  end

  test "no offense when all private methods are called" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run
              helper
              other_helper
            end

            private
              def helper; end
              def other_helper; end
          end
      end
    RUBY
  end

  test "no offense for nested class not in private section" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        class Bar
          def run; end

          private
            def unused; end
        end

        def process
          Bar.new.run
        end
      end
    RUBY
  end

  test "no offense when private method is referenced by callback" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            after_initialize :setup

            def run; end

            private
              def setup; end
          end
      end
    RUBY
  end

  test "no offense for public methods in private nested class" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run; end
            def unused_but_public; end
          end
      end
    RUBY
  end

  test "detects multiple unused private methods" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run; end

            private
              def unused_one; end
              def unused_two; end
          end
      end
    RUBY

    assert_equal 2, offenses.count
  end

  test "works in modules" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      module Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run; end

            private
              def unused; end
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
