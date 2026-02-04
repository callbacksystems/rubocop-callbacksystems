require "test_helper"

class NoNestedModulesInClassesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoNestedModulesInClasses

  test "registers offense for nested module in class" do
    offenses = assert_offense <<~RUBY
      class Order
        module Calculations
          def total
          end
        end
      end
    RUBY
    assert_includes offenses.first.message, "Do not nest modules"
  end

  test "registers offense for nested module in private section" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          module Helper
            def help
            end
          end
      end
    RUBY
    assert_includes offenses.first.message, "Do not nest modules"
  end

  test "registers offense for deeply nested module in class" do
    offenses = assert_offense <<~RUBY
      class Outer
        class Inner
          module Deeply
          end
        end
      end
    RUBY
    assert_includes offenses.first.message, "Do not nest modules"
  end

  test "allows nested classes in classes" do
    assert_no_offense <<~RUBY
      class Order
        private
          class Calculator
            def total
            end
          end
      end
    RUBY
  end

  test "allows modules at top level" do
    assert_no_offense <<~RUBY
      module Calculations
        def total
        end
      end
    RUBY
  end

  test "allows modules inside modules" do
    assert_no_offense <<~RUBY
      module Outer
        module Inner
          def calculate
          end
        end
      end
    RUBY
  end

  test "allows classes inside modules" do
    assert_no_offense <<~RUBY
      module Outer
        class Inner
          def calculate
          end
        end
      end
    RUBY
  end
end
