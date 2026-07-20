require "test_helper"

class RuboCop::Cop::Callbacksystems::PrivateMethodsInPrivateSectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateMethodsInPrivateSection

  test "registers offense for a method defined in the same body" do
    offenses = assert_offense <<~RUBY
      class Report
        def total
        end
        private :total
      end
    RUBY

    assert_includes offenses.first.message, "total"
  end

  test "registers an offense for every method it names" do
    offenses = assert_offense <<~RUBY
      class Report
        def total
        end

        def rate
        end

        private :total, :rate
      end
    RUBY

    assert_equal 2, offenses.size
  end

  test "allows marking a reader that comes from the superclass" do
    assert_no_offense <<~RUBY
      class Request < Data.define(:command, :lock_held)
        alias lock_held? lock_held

        def initialize(command:, lock_held:)
          super
        end

        private :lock_held
      end
    RUBY
  end

  test "allows marking a method a macro generated" do
    assert_no_offense <<~RUBY
      class Report
        attr_reader :order

        private :order
      end
    RUBY
  end

  test "allows the private keyword opening a section" do
    assert_no_offense <<~RUBY
      class Report
        private
          def total
          end
      end
    RUBY
  end

  test "allows marking a method defined in the singleton section" do
    assert_no_offense <<~RUBY
      class Report
        class << self
          def build
          end
        end

        private :build
      end
    RUBY
  end
end
