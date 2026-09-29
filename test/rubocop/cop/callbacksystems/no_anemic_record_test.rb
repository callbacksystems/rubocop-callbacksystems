require "test_helper"

class RuboCop::Cop::Callbacksystems::NoAnemicRecordTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAnemicRecord

  test "registers offense for a constant record whose fields several methods read" do
    offenses = assert_offense <<~RUBY
      class Collapse
        SHAPE = { open: "{", close: "}", items: :children }

        def opening?
          source == SHAPE[:open]
        end

        def items
          node.public_send(SHAPE[:items])
        end
      end
    RUBY

    assert_includes offenses.first.message, "carries [open, close, items]"
    assert_includes offenses.first.message, "2 methods reach into its fields"
  end

  test "ignores reads of fields the record does not carry" do
    offenses = assert_offense <<~RUBY
      class Collapse
        SHAPE = { open: "{", close: "}", items: :children }

        def opening?
          source == SHAPE[:open]
        end

        def items
          node.public_send(SHAPE[:items])
        end

        def unrelated
          SHAPE[:missing]
        end
      end
    RUBY

    assert_includes offenses.first.message, "2 methods reach into its fields"
  end

  test "registers offense for a record assigned to an instance variable" do
    assert_offense <<~RUBY
      class Report
        def initialize
          @options = { width: 1, height: 2, depth: 3 }
        end

        def wide?
          @options[:width] > 10
        end

        def tall?
          @options[:height] > 10
        end
      end
    RUBY
  end

  test "registers offense for a record assigned to a class variable" do
    assert_offense <<~RUBY
      class Report
        @@options = { width: 1, height: 2, depth: 3 }

        def wide?
          @@options[:width] > 10
        end

        def tall?
          @@options[:height] > 10
        end
      end
    RUBY
  end

  test "registers offense for a record a method returns" do
    assert_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          settings[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "registers offense for fields read through fetch and dig" do
    assert_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening
          SHAPE.fetch(:open)
        end

        def closing
          SHAPE.dig(:close)
        end
      end
    RUBY
  end

  test "allows a record built and consumed on the spot" do
    assert_no_offense <<~RUBY
      class Report
        def render_json
          render json: { status: "ok", width: 1, height: 2 }
        end

        def wide?
          payload[:width] > 10
        end

        def tall?
          payload[:height] > 10
        end
      end
    RUBY
  end

  test "allows a record only one method reaches into" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening?
          SHAPE[:open] == SHAPE[:close]
        end
      end
    RUBY
  end

  test "allows a record of two fields, which is below the minimum" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}" }

        def opening
          SHAPE[:open]
        end

        def closing
          SHAPE[:close]
        end
      end
    RUBY
  end

  test "allows reads that share a single field with the record" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def width
          settings[:open]
        end

        def height
          settings[:height]
        end
      end
    RUBY
  end

  test "allows a record whose keys are not symbols" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { "open" => "{", "close" => "}", "items" => :children }

        def opening
          SHAPE["open"]
        end

        def closing
          SHAPE["close"]
        end
      end
    RUBY
  end

  test "allows a hash read with a variable rather than a field name" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def part(name)
          SHAPE[name]
        end

        def other(name)
          SHAPE[name]
        end
      end
    RUBY
  end

  test "registers offense for a record closing a method that holds more statements" do
    assert_offense <<~RUBY
      class Report
        def settings
          defaults = 1
          { width: defaults, height: 2, depth: 3 }
        end

        def wide?
          settings[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "allows fields read from a bare call, which names no record" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening
          fetch(:open)
        end

        def closing
          fetch(:close)
        end
      end
    RUBY
  end

  test "allows fields read from another object, whose record is not this one" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening
          other.shape[:open]
        end

        def closing
          other.shape[:close]
        end
      end
    RUBY
  end

  test "allows reads through another receiver with the record method name" do
    assert_no_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          other.settings[:width] > 10
        end

        def tall?
          other.settings[:height] > 10
        end
      end
    RUBY
  end

  test "registers reads through an explicit self receiver" do
    assert_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          self.settings[:width] > 10
        end

        def tall?
          self.settings[:height] > 10
        end
      end
    RUBY
  end

  test "does not combine an unqualified record with reads from a qualified constant" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening
          Other::SHAPE[:open]
        end

        def closing
          Other::SHAPE[:close]
        end
      end
    RUBY
  end

  test "does not combine instance and singleton records returned by the same method name" do
    assert_no_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def self.wide?
          settings[:width] > 10
        end

        def self.tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "allows a record the whole file consists of, which travels nowhere" do
    assert_no_offense <<~RUBY
      { width: sizes[:width], height: sizes[:height], depth: 3 }
    RUBY
  end

  test "allows a record dropped at the top level, which no one keeps" do
    assert_no_offense <<~RUBY
      { width: 1, height: 2, depth: 3 }

      def wide?
        sizes[:width] > 10
      end

      def tall?
        sizes[:height] > 10
      end
    RUBY
  end

  test "gives its reads to the record they come from rather than a wider one sharing its fields" do
    offenses = assert_offense <<~RUBY, count: 1
      class Report
        NARROW = { width: 1, height: 2, depth: 3 }
        WIDE = { width: 1, height: 2, depth: 3, weight: 4, color: 5 }

        def wide?
          NARROW[:width] > NARROW[:height]
        end

        def deep?
          NARROW[:depth] > 1
        end
      end
    RUBY

    assert_includes offenses.first.message, "carries [width, height, depth]"
  end

  test "registers offense for a returned record read through a local assigned from its method" do
    assert_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          config = settings
          config[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "does not follow a local rebound by pattern matching back to a record" do
    assert_no_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?(input)
          config = settings
          input => { config: }
          config[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "ignores a same-named local assignment inside a nested method" do
    assert_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          config = settings

          Class.new do
            def unrelated
              config = other
            end
          end

          config[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "allows a read through a local copied from another local, which names no record" do
    assert_no_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def wide?
          config = settings
          copy = config
          copy[:width] > 10
        end

        def tall?
          settings[:height] > 10
        end
      end
    RUBY
  end

  test "allows reads on an unrelated base that shares two of the fields" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }

        def opening(entry)
          entry[:open]
        end

        def closing(entry)
          entry[:close]
        end
      end
    RUBY
  end

  test "allows a hash returned from as_json, which is the wire format" do
    assert_no_offense <<~RUBY
      class Listing
        def as_json(*)
          { id: id, name: name, rules: rules }
        end

        def identified?
          as_json[:id].present?
        end

        def ruled?
          as_json[:rules].any?
        end
      end
    RUBY
  end

  test "allows a serialized hash whose keys a form entry shares" do
    assert_no_offense <<~RUBY
      class Composition
        class << self
          def compose(entries)
            entries.map { |entry| new(entry[:id]) }
          end
        end

        def as_json(*)
          {
            id: listing.id, name: listing.name, description: listing.description,
            priceAmount: listing.price_amount, ctaText: listing.cta_text,
            priceCurrency: currency, errors: listing.errors.to_hash, rules: rules_as_json
          }
        end

        private
          def build_rules(entry)
            Array(entry[:rules]).map { |rule_attributes| rule_attributes[:id] }
          end
      end
    RUBY
  end

  test "does not combine identically named records from separate classes" do
    assert_no_offense <<~RUBY
      class FirstReport
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        def width
          settings[:width]
        end
      end

      class SecondReport
        def settings
          { width: 4, height: 5, depth: 6 }
        end

        def height
          settings[:height]
        end
      end
    RUBY
  end

  test "does not combine a returned record with same-named calls in an anonymous class" do
    assert_no_offense <<~RUBY
      class Report
        def settings
          { width: 1, height: 2, depth: 3 }
        end

        Handler = Class.new do
          def wide?
            settings[:width] > 10
          end

          def tall?
            settings[:height] > 10
          end
        end
      end
    RUBY
  end

  test "keeps many independent records paired only with their own readers" do
    record_count = 500
    records = record_count.times.map { "  RECORD_#{it} = { first: 1, second: 2, third: 3 }" }.join("\n")
    readers = record_count.times.flat_map do |index|
      [ "  def first_#{index}; RECORD_#{index}[:first]; end", "  def second_#{index}; RECORD_#{index}[:second]; end" ]
    end.join("\n")

    assert_offense "class Records\n#{records}\n#{readers}\nend\n", count: record_count
  end

  test "does not count a class-level read as another reading method" do
    assert_no_offense <<~RUBY
      class Report
        SHAPE = { open: "{", close: "}", items: :children }
        OPEN = SHAPE[:open]

        def closing
          SHAPE[:close]
        end
      end
    RUBY
  end
end
