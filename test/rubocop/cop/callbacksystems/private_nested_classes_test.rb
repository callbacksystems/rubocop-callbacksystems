require "test_helper"

class RuboCop::Cop::Callbacksystems::PrivateNestedClassesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateNestedClasses

  test "registers offense for public nested class" do
    assert_offense <<~RUBY
      class Order
        class LineItem
          def total
          end
        end
      end
    RUBY
  end

  test "registers offense for nested class before private keyword" do
    assert_offense <<~RUBY
      class Order
        class LineItem
          def total
          end
        end

        private
          def process
          end
      end
    RUBY
  end

  test "registers offense for a public constant building a Data class with behavior" do
    offenses = assert_offense <<~RUBY
      class Order
        LineItem = Data.define(:sku, :quantity) do
          def total
            sku
          end
        end

        private
          def process
          end
      end
    RUBY

    assert_includes offenses.first.message, "LineItem"
    assert_includes offenses.first.message, "its own file"
  end

  test "registers offense for a Struct with behavior" do
    assert_offense <<~RUBY
      class Order
        LineItem = Struct.new(:sku, keyword_init: true) do
          def total
            sku
          end
        end
      end
    RUBY
  end

  test "registers offense for an anonymous class with behavior" do
    assert_offense <<~RUBY
      class Order
        LineItem = Class.new(Base) do
          def total
          end
        end
      end
    RUBY
  end

  test "allows a constant building a class in the private section" do
    assert_no_offense <<~RUBY
      class Order
        def process
        end

        private
          LineItem = Data.define(:sku) do
            def total
              sku
            end
          end
      end
    RUBY
  end

  test "allows a declaration with no body" do
    assert_no_offense <<~RUBY
      class Order
        LineItem = Data.define(:sku, :quantity)
        Position = Struct.new(:row, :column)
      end
    RUBY
  end

  test "allows an empty error class" do
    assert_no_offense <<~RUBY
      class Order
        class Rejected < StandardError; end

        def process
        end
      end
    RUBY
  end

  test "allows constants that do not build a class" do
    assert_no_offense <<~RUBY
      class Order
        FORMATS = [ :json ].freeze
        LIMIT = 10
        MATCHER = Data::TYPES.first
      end
    RUBY
  end

  test "does not flag a top-level constant building a class" do
    assert_no_offense <<~RUBY
      LineItem = Data.define(:sku) do
        def total
          sku
        end
      end
    RUBY
  end

  test "allows nested class in private section" do
    assert_no_offense <<~RUBY
      class Order
        def process
        end

        private
          class LineItem
          end
      end
    RUBY
  end

  test "allows nested class after private with methods before" do
    assert_no_offense <<~RUBY
      class Order
        def process
        end

        private
          def internal
          end

          class LineItem
          end
      end
    RUBY
  end

  test "allows multiple nested classes in private section" do
    assert_no_offense <<~RUBY
      class Order
        private
          class LineItem
          end

          class Discount
          end
      end
    RUBY
  end

  test "registers offense for nested class in module" do
    assert_offense <<~RUBY
      module Orders
        class LineItem
          def total
          end
        end
      end
    RUBY
  end

  test "allows singleton class (class << self)" do
    assert_no_offense <<~RUBY
      class Order
        class << self
          def find_all
          end
        end
      end
    RUBY
  end

  test "does not flag top-level classes" do
    assert_no_offense <<~RUBY
      class Order
      end
    RUBY
  end

  test "allows nested class in private section at end" do
    assert_no_offense <<~RUBY
      class Parser
        def parse
          Tokenizer.new(input).tokens
        end

        private
          attr_reader :input

          class Tokenizer
            def initialize(input)
              @input = input
            end

            def tokens
              input.split
            end
          end
      end
    RUBY
  end
end
