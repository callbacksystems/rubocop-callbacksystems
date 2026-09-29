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

  test "removes a same-line empty section without deleting the method beside it" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Order
        def total = 10; private
      end
    RUBY
      class Order
        def total = 10
      end
    CORRECTED
  end

  test "moves a same-line comment off the statement whose private section disappears" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Order
        def total = 10; private # The internal API ends here.
      end
    RUBY
      class Order
        def total = 10
        # The internal API ends here.
      end
    CORRECTED
  end

  test "reports without moving a same-line tooling directive" do
    assert_uncorrectable_offense <<~RUBY
      class Order
        def total = 10; private # :nocov:
      end
    RUBY
  end

  test "reports without dropping a tooling directive from a standalone empty section" do
    assert_uncorrectable_offense <<~RUBY
      class Order
        def total
        end

        private # :nocov:
      end
    RUBY
  end

  test "removes an empty section when the containing class value is demonstrably ignored" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Registry
        class Order
          def total
          end

          private
        end

        LOADED = true
      end
    RUBY
      class Registry
        class Order
          def total
          end
        end

        LOADED = true
      end
    CORRECTED
  end

  test "reports without a fix when the containing class value is assigned" do
    assert_uncorrectable_offense <<~RUBY
      RESULT = class Order
        def total
        end

        private
      end
    RUBY
  end

  test "reports without a fix when a callable returns the containing class value" do
    assert_uncorrectable_offense <<~RUBY
      LOADER = -> do
        class Order
          def total
          end

          private
        end
      end
    RUBY
  end

  test "reports without a fix when the containing class is passed as an argument" do
    assert_uncorrectable_offense <<~RUBY
      register(class Order
        def total
        end

        private
      end)
    RUBY
  end

  test "allows a private modifier written at the top level, outside any definition" do
    assert_no_offense <<~RUBY
      private

      def helper
      end
    RUBY
  end
end
