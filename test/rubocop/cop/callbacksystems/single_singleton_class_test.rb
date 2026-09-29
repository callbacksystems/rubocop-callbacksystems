require "test_helper"

class RuboCop::Cop::Callbacksystems::SingleSingletonClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleSingletonClass

  test "registers offense for a second singleton section" do
    offenses = assert_offense <<~RUBY, count: 1
      class Configuration
        class << self
          def create_from(file)
          end
        end

        def initialize(raw_config)
        end

        class << self
          private
            def load_config_files(file)
            end
        end
      end
    RUBY

    assert_includes offenses.first.message, "single singleton section"
  end

  test "registers an offense for every extra singleton section" do
    assert_offense <<~RUBY, count: 2
      class Configuration
        class << self
          def first
          end
        end

        class << self
          def second
          end
        end

        class << self
          def third
          end
        end
      end
    RUBY
  end

  test "allows a single singleton section" do
    assert_no_offense <<~RUBY
      class Configuration
        class << self
          def create_from(file)
          end

          private
            def load_config_files(file)
            end
        end

        def initialize(raw_config)
        end
      end
    RUBY
  end

  test "allows singleton sections in separate classes" do
    assert_no_offense <<~RUBY
      class Configuration
        class << self
          def create_from(file)
          end
        end

        private
          class Validator
            class << self
              def call(config)
              end
            end
          end
      end
    RUBY
  end

  test "allows singleton classes of other objects" do
    assert_no_offense <<~RUBY
      class Configuration
        class << self
          def create_from(file)
          end
        end

        class << OTHER
          def call
          end
        end
      end
    RUBY
  end
end
