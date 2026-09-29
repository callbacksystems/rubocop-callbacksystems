require "test_helper"

class RuboCop::Cop::Callbacksystems::NestedClassOrderTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NestedClassOrder
  self.project_indexed = true

  test "registers offense when a class sits before the one that names it" do
    offenses = assert_offense <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY

    assert_includes offenses.first.message, "Class `Row` should be defined before `Cell`"
  end

  test "registers offense for a nested module naming another" do
    assert_offense <<~RUBY
      module Wrapper
        module Formatting
          def format
          end
        end

        module Rendering
          def render
            Formatting.format
          end
        end
      end
    RUBY
  end

  test "allows a class written before the ones it names" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Cell
          def value
          end
        end
      end
    RUBY
  end

  test "allows classes that name nothing of each other" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def name
          end
        end

        class Cell
          def value
          end
        end
      end
    RUBY
  end

  test "allows a qualified reference to a different class carrying the same short name" do
    project_sources = {
      "app/models/other.rb" => <<~RUBY
        class Other
          class Cell
          end
        end
      RUBY
    }

    assert_no_offense <<~RUBY, project_sources:
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Other::Cell.new ]
          end
        end
      end
    RUBY
  end

  test "does not infer reference identity without the project index" do
    assert_no_offense <<~RUBY, project_sources: false
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY
  end

  test "allows a base class written before the ones inheriting from it" do
    assert_no_offense <<~RUBY
      class Report
        class Base
          def render
          end
        end

        class Detailed < Base
          def render
            super
          end
        end
      end
    RUBY
  end

  test "allows a class reading another outside a method, which the body reads while it loads" do
    assert_no_offense <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        class Row
          HEADER = Cell.new

          def cells
          end
        end
      end
    RUBY
  end

  test "allows a run whose reference order would place a class before the one it inherits from" do
    assert_no_offense <<~RUBY
      class Report
        class Base
          def render
          end
        end

        class Row < Base
          def cells
            Base.new
          end
        end
      end
    RUBY
  end

  test "allows a single nested class" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def cells
            Row.new
          end
        end
      end
    RUBY
  end

  test "allows classes a method definition keeps apart" do
    assert_no_offense <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        def rows
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY
  end

  test "allows a constant built in a line, which BodyOrder reads with the values" do
    assert_no_offense <<~RUBY
      class Report
        Cell = Data.define(:value)

        class Row
          def cells
            [ Cell.new(1) ]
          end
        end
      end
    RUBY
  end

  test "reorders the run so each class reads before the ones it names" do
    original = <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Cell
          def value
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "carries the comments written above a class it moves" do
    original = <<~RUBY
      class Report
        # One cell of a row.
        class Cell
          def value
          end
        end

        # One row of the report.
        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        # One row of the report.
        class Row
          def cells
            [ Cell.new ]
          end
        end

        # One cell of a row.
        class Cell
          def value
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "reports without moving a class whose tooling directive would change scope" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        # :nocov:
        class Row
          def cells
            [ Cell.new ]
          end
        end
        # :nocov:
      end
    RUBY
  end

  test "reads a chain of three classes depth first" do
    original = <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Table
          def rows
            [ Row.new ]
          end
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        class Table
          def rows
            [ Row.new ]
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Cell
          def value
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "leaves a run whose classes name each other in a cycle" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Cell
          def row
            Row.new
          end
        end
      end
    RUBY
  end

  test "leaves reopened nested classes in their written order" do
    source = <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end

        class Cell
          def row
            Row.new
          end
        end
      end
    RUBY

    assert_no_offense source
    assert_no_correction source
  end

  test "reports without ordering nested classes across an independent comment" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        class Cell
          def value
          end
        end

        # Rows compose cells.

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY
  end

  test "allows a constant built from a builder with a block, which another cop asks to be a class" do
    assert_no_offense <<~RUBY
      class Report
        Cell = Class.new do
          def value
          end
        end

        class Row
          def cells
            [ Cell.new ]
          end
        end
      end
    RUBY
  end

  test "allows a Struct built with a block beside a class naming it" do
    assert_no_offense <<~RUBY
      class Report
        Cell = Struct.new(:value) do
          def to_s
            value.to_s
          end
        end

        class Row
          def cells
            [ Cell.new(1) ]
          end
        end
      end
    RUBY
  end
end
