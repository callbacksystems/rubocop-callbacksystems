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

  test "allows a constant that builds nothing" do
    assert_no_offense <<~RUBY
      FORMATS = [ :json ].freeze
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
    assert_correction source, source
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
end
