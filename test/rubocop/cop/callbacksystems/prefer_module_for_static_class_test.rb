require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferModuleForStaticClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferModuleForStaticClass

  test "registers offense for a singleton section with a private part" do
    offenses = assert_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            normalize(reports)
          end

          private
            def normalize(raw)
              raw.downcase
            end
        end
      end
    RUBY

    assert_includes offenses.first.message, "extend self"
  end

  test "registers offense alongside constants and extends" do
    assert_offense <<~RUBY
      class Architecture
        extend Comparable

        NAMES = { "arm64" => "arm64" }.freeze

        class << self
          def resolve(raw)
            normalize(raw)
          end

          private
            def normalize(raw)
              NAMES.fetch(raw)
            end
        end
      end
    RUBY
  end

  test "allows a singleton section without a private part" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            reports.first
          end
        end
      end
    RUBY
  end

  test "allows a class with instance methods" do
    assert_no_offense <<~RUBY
      class Architecture
        def resolve
        end

        class << self
          def build
            new
          end

          private
            def default
            end
        end
      end
    RUBY
  end

  test "allows a class with a superclass" do
    assert_no_offense <<~RUBY
      class Architecture < Base
        class << self
          def resolve(reports)
            normalize(reports)
          end

          private
            def normalize(raw)
              raw
            end
        end
      end
    RUBY
  end

  test "allows a class whose private section holds instance state" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            reports
          end
        end

        private
          attr_reader :name
      end
    RUBY
  end
end
