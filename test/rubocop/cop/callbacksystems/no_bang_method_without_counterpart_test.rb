require "test_helper"

class RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpartTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpart

  test "registers offense for bang method without counterpart" do
    assert_offense <<~RUBY
      class Example
        def process!
        end
      end
    RUBY
  end

  test "allows bang method with non-bang counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def save
        end

        def save!
        end
      end
    RUBY
  end

  test "allows non-bang methods" do
    assert_no_offense <<~RUBY
      class Example
        def process
        end

        def validate
        end
      end
    RUBY
  end

  test "allows bang method when counterpart is defined after" do
    assert_no_offense <<~RUBY
      class Example
        def save!
        end

        def save
        end
      end
    RUBY
  end

  test "registers offense for multiple bang methods without counterparts" do
    offenses = assert_offense <<~RUBY
      class Example
        def process!
        end

        def validate!
        end
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "checks class methods too" do
    assert_offense <<~RUBY
      class Example
        def self.build!
        end
      end
    RUBY
  end

  test "allows class method bang with counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def self.build
        end

        def self.build!
        end
      end
    RUBY
  end

  test "works in modules" do
    assert_offense <<~RUBY
      module Example
        def process!
        end
      end
    RUBY
  end

  test "allows bang in module with counterpart" do
    assert_no_offense <<~RUBY
      module Example
        def process
        end

        def process!
        end
      end
    RUBY
  end

  test "handles private methods" do
    assert_no_offense <<~RUBY
      class Example
        def save
        end

        private
          def save!
          end
      end
    RUBY
  end

  test "handles empty class" do
    assert_no_offense <<~RUBY
      class Example
      end
    RUBY
  end

  test "handles class with only non-bang methods" do
    assert_no_offense <<~RUBY
      class Example
        def foo
        end

        def bar
        end
      end
    RUBY
  end

  test "does not consider counterpart from nested class" do
    assert_offense <<~RUBY
      class Outer
        def save!
        end

        private
          class Inner
            def save
            end
          end
      end
    RUBY
  end

  test "does not consider counterpart from outer class" do
    assert_offense <<~RUBY
      class Outer
        def save
        end

        private
          class Inner
            def save!
            end
          end
      end
    RUBY
  end

  test "each nested class is analyzed independently" do
    offenses = assert_offense <<~RUBY
      class Outer
        def process!
        end

        private
          class Inner
            def validate!
            end
          end
      end
    RUBY

    assert_equal 2, offenses.count
  end

  test "allows bang method in nested class when counterpart exists in same nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def save
            end

            def save!
            end
          end
      end
    RUBY
  end

  test "nested class bang methods are independent from outer class" do
    assert_no_offense <<~RUBY
      class Outer
        def save
        end

        def save!
        end

        private
          class Inner
            def process
            end

            def process!
            end
          end
      end
    RUBY
  end
end
