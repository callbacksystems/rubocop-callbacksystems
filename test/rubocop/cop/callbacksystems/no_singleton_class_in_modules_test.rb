require "test_helper"

class NoSingletonClassInModulesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoSingletonClassInModules

  test "registers offense for class << self in module" do
    offenses = assert_offense <<~RUBY
      module Calculator
        class << self
          def add(a, b)
            a + b
          end
        end
      end
    RUBY
    assert_includes offenses.first.message, "extend self"
  end

  test "registers offense for class << self in nested module" do
    offenses = assert_offense <<~RUBY
      module Outer
        module Inner
          class << self
            def calculate
            end
          end
        end
      end
    RUBY
    assert_includes offenses.first.message, "extend self"
  end

  test "allows class << self in classes" do
    assert_no_offense <<~RUBY
      class Calculator
        class << self
          def add(a, b)
            a + b
          end
        end
      end
    RUBY
  end

  test "allows extend self in modules" do
    assert_no_offense <<~RUBY
      module Calculator
        extend self

        def add(a, b)
          a + b
        end
      end
    RUBY
  end

  test "allows class << self in class inside module" do
    assert_no_offense <<~RUBY
      module Outer
        class Inner
          class << self
            def calculate
            end
          end
        end
      end
    RUBY
  end
end
