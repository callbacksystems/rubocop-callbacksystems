require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferClassNewForEmptyNestedClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferClassNewForEmptyNestedClass

  test "registers offense for an empty nested class on one line" do
    offenses = assert_offense <<~RUBY
      class Configuration
        class Error < StandardError; end

        def call
        end
      end
    RUBY

    assert_includes offenses.first.message, "Error"
    assert_includes offenses.first.message, "Class.new"
  end

  test "registers offense for an empty nested class over two lines" do
    assert_offense <<~RUBY
      class Configuration
        class Error < StandardError
        end
      end
    RUBY
  end

  test "registers offense for an empty nested class without a superclass" do
    assert_offense <<~RUBY
      class Configuration
        class Marker; end
      end
    RUBY
  end

  test "registers offense inside a module" do
    assert_offense <<~RUBY
      module PgBox
        class Error < StandardError; end
      end
    RUBY
  end

  test "allows a nested class with a body" do
    assert_no_offense <<~RUBY
      class Configuration
        class Error < StandardError
          def message
            "boom"
          end
        end
      end
    RUBY
  end

  test "allows an empty class at the top level" do
    assert_no_offense <<~RUBY
      class PgBox::ConfigurationError < StandardError; end
    RUBY
  end

  test "allows a constant already declaring the class" do
    assert_no_offense <<~RUBY
      class Configuration
        Error = Class.new(StandardError)
      end
    RUBY
  end

  test "autocorrects to a constant carrying the superclass" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Error < StandardError; end

          def call
          end
        end
      RUBY
      <<~RUBY
        class Configuration
          Error = Class.new(StandardError)

          def call
          end
        end
      RUBY
  end

  test "autocorrects the two-line form" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Marker
          end
        end
      RUBY
      <<~RUBY
        class Configuration
          Marker = Class.new
        end
      RUBY
  end
end
