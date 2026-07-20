require "test_helper"

class RuboCop::Cop::Callbacksystems::EmptyPrivateSectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EmptyPrivateSection

  test "registers offense for a private section holding nothing" do
    offenses = assert_offense <<~RUBY
      class Order
        def total
        end

        private
      end
    RUBY

    assert_includes offenses.first.message, "empty `private` section"
  end

  test "registers offense in a module" do
    assert_offense <<~RUBY
      module Billing
        def total
        end

        private
      end
    RUBY
  end

  test "registers offense inside a singleton section" do
    assert_offense <<~RUBY
      class Order
        class << self
          def build
          end

          private
        end
      end
    RUBY
  end

  test "allows a private section holding methods" do
    assert_no_offense <<~RUBY
      class Order
        def total
        end

        private
          def rate
          end
      end
    RUBY
  end

  test "allows a private section holding declarations" do
    assert_no_offense <<~RUBY
      class Order
        def total
        end

        private
          attr_reader :lines
      end
    RUBY
  end

  test "allows a private section holding a nested class" do
    assert_no_offense <<~RUBY
      class Order
        def total
        end

        private
          class Line
          end
      end
    RUBY
  end

  test "allows a private call taking arguments" do
    assert_no_offense <<~RUBY
      class Order
        def total
        end

        private :total
      end
    RUBY
  end

  test "autocorrects by removing the section and the blank line above it" do
    assert_correction \
      <<~RUBY,
        class Order
          def total
          end

          private
        end
      RUBY
      <<~RUBY
        class Order
          def total
          end
        end
      RUBY
  end
end
