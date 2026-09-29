require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferClassOverBuilderBlockTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferClassOverBuilderBlock

  test "registers offense for a Data builder taking a block" do
    offenses = assert_offense <<~RUBY
      Route = Data.define(:host) do
        def matches?(other)
          host == other
        end
      end
    RUBY

    assert_includes offenses.first.message, "Route"
    assert_includes offenses.first.message, "Data.define"
  end

  test "registers offense for a Struct builder taking a block" do
    assert_offense <<~RUBY
      Position = Struct.new(:row, :column) do
        def to_s
          row
        end
      end
    RUBY
  end

  test "registers offense for an anonymous class taking a block" do
    assert_offense <<~RUBY
      Probe = Class.new(Base) do
        def call
        end
      end
    RUBY
  end

  test "allows a builder with no block" do
    assert_no_offense <<~RUBY
      Entry = Data.define(:sku, :quantity)
    RUBY
  end

  test "allows a builder with an empty or comment-only block" do
    assert_no_offense <<~RUBY
      Entry = Data.define(:sku) do
      end

      Position = Struct.new(:row, :column) do
        # Positional value object.
      end
    RUBY
  end

  test "allows Module builders and namespaced builder lookalikes" do
    assert_no_offense <<~RUBY
      Namespace = Module.new do
        def available? = true
      end

      Entry = Domain::Data.define(:sku) do
        def total = 1
      end
    RUBY
  end

  test "allows a constant that builds nothing" do
    assert_no_offense <<~RUBY
      FORMATS = [ :json ]
    RUBY
  end

  test "allows a class already inheriting from a builder" do
    assert_no_offense <<~RUBY
      class Route < Data.define(:host)
        def matches?(other)
          host == other
        end
      end
    RUBY
  end

  test "autocorrects a nested builder keeping its body" do
    assert_correction \
      <<~RUBY,
        class Verification
          private
            Result = Data.define(:host, :output) do
              def to_s
                output
              end
            end
        end
      RUBY
      <<~RUBY
        class Verification
          private
            class Result < Data.define(:host, :output)
              def to_s
                output
              end
            end
        end
      RUBY
  end

  test "reports a brace block without rewriting it" do
    source = <<~RUBY
      Route = Data.define(:host) { def matches?(other) = host == other }
    RUBY

    assert_offense source
    assert_no_correction source
  end

  test "reports an implicit parameter builder block without crashing or rewriting it" do
    source = <<~RUBY
      Route = Data.define(:host) do
        consume(it)
      end
    RUBY

    assert_uncorrectable_offense source
  end

  test "autocorrects Class.new to inherit from its argument" do
    assert_correction \
      <<~RUBY,
        class Foo
          LoggerProbe = Class.new(BaseLogger) do
            def call
            end
          end
        end
      RUBY
      <<~RUBY
        class Foo
          class LoggerProbe < BaseLogger
            def call
            end
          end
        end
      RUBY
  end

  test "autocorrects an argumentless Class.new to a plain class" do
    assert_correction \
      <<~RUBY,
        class Foo
          Probe = Class.new do
            def call
            end
          end
        end
      RUBY
      <<~RUBY
        class Foo
          class Probe
            def call
            end
          end
        end
      RUBY
  end

  test "autocorrects without dropping the namespace from the assigned constant" do
    assert_correction <<~RUBY, <<~CORRECTED
      Domain::Route = Data.define(:host) do
        def matches?(other)
          host == other
        end
      end
    RUBY
      class Domain::Route < Data.define(:host)
        def matches?(other)
          host == other
        end
      end
    CORRECTED
  end

  test "leaves a builder that closes over a local variable for a human" do
    assert_uncorrectable_offense <<~RUBY
      prefix = "https"
      Route = Class.new do
        define_method(:url) { "\#{prefix}://example.com" }
      end
    RUBY
  end

  test "leaves constant assignment in the builder's lexical namespace" do
    assert_uncorrectable_offense <<~RUBY
      module Outer
        Route = Class.new do
          VALUE = :inside
        end
      end
    RUBY
  end

  test "leaves constant references with the builder's lexical lookup" do
    assert_uncorrectable_offense <<~RUBY
      module Outer
        VALUE = :outside

        Route = Class.new do
          def value
            Outer::VALUE
          end
        end
      end
    RUBY
  end

  test "leaves class variables with the builder's lexical owner" do
    assert_uncorrectable_offense <<~RUBY
      class Outer
        @@value = :outside

        Route = Class.new do
          @@value = :inside
        end
      end
    RUBY
  end

  test "reports block-local control flow without writing it into a class body" do
    %w[ break next redo ].each do |flow|
      assert_uncorrectable_offense <<~RUBY
        class Registry
          Entry = Class.new do
            #{flow}
          end
        end
      RUBY
    end
  end

  test "autocorrects control flow owned by a block nested inside the builder" do
    assert_correction <<~BAD, <<~GOOD
      class Registry
        Entry = Class.new do
          [ 1 ].each { break }
        end
      end
    BAD
      class Registry
        class Entry
          [ 1 ].each { break }
        end
      end
    GOOD
  end

  test "autocorrects control flow owned by a nested implicit parameter block" do
    assert_correction <<~BAD, <<~GOOD
      class Registry
        Entry = Class.new do
          [ 1 ].each { consume(it); break }
        end
      end
    BAD
      class Registry
        class Entry
          [ 1 ].each { consume(it); break }
        end
      end
    GOOD
  end
end
