require "test_helper"

class NestedClassesAtEndOfPrivateSectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NestedClassesAtEndOfPrivateSection

  test "registers offense for method after nested class" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          class Bar
            def call
            end
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
            def call
            end
          end
      end
    RUBY
  end

  test "registers offense for method after a class builder with a block" do
    offenses = assert_offense <<~RUBY
      class Verification
        def run_once
          execute_once
        end

        private
          Result = Data.define(:host, :output) do
            def to_s
              output
            end
          end

          def execute_once
            Result.new(host: host, output: "")
          end
      end
    RUBY

    assert_includes offenses.first.message, "Result"
    assert_includes offenses.first.message, "execute_once"
  end

  test "no offense when the class builder closes the private section" do
    assert_no_offense <<~RUBY
      class Verification
        private
          def execute_once
            Result.new(host: host)
          end

          Result = Data.define(:host) do
            def to_s
              host
            end
          end
      end
    RUBY
  end

  test "no offense for a class builder with no block" do
    assert_no_offense <<~RUBY
      class Verification
        private
          Result = Data.define(:host, :output)

          def execute_once
            Result.new(host: host, output: "")
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
            def call
            end
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
            def call
            end
          end

          def helper
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
