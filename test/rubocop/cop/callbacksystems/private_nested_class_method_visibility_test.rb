require "test_helper"

class PrivateNestedClassMethodVisibilityTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateNestedClassMethodVisibility

  test "registers offense for unused public method in private nested class" do
    offenses = assert_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).used_method
        end

        private
          class Bar
            def used_method; end
            def unused_method; end
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "unused_method"
  end

  test "no offense when all public methods are called from outside" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          bar = Bar.new(node)
          bar.method_one
          bar.method_two
        end

        private
          class Bar
            def method_one; end
            def method_two; end
          end
      end
    RUBY
  end

  test "no offense for private methods in nested class" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).public_method
        end

        private
          class Bar
            def public_method
              private_helper
            end

            private
              def private_helper; end
          end
      end
    RUBY
  end

  test "no offense for nested class not in private section" do
    assert_no_offense <<~RUBY
      class Foo
        class Bar
          def unused_method; end
        end

        def process
          Bar.new(node).other_method
        end
      end
    RUBY
  end

  test "no offense for initialize method" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).used
        end

        private
          class Bar
            def initialize(node)
              @node = node
            end

            def used; end
          end
      end
    RUBY
  end

  test "no offense for method referenced by callback symbol" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            after_initialize :setup

            def run; end

            def setup
              @ready = true
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by delegate to: symbol" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            delegate :present?, to: :record

            def run; end

            def record
              @record ||= find_record
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by delegate to: string chain" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            delegate :name, to: "config.settings"

            def run; end

            def config
              @config ||= load_config
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by lambda callback" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            before_action -> { prepare_data }

            def run; end

            def prepare_data
              @data = []
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced in callback if: option" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            after_save :notify, if: :should_notify?

            def run; end

            def notify; end

            def should_notify?
              true
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced in callback unless: option" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            before_save :validate_data, unless: :skip_validation?

            def run; end

            def validate_data; end

            def skip_validation?
              false
            end
          end
      end
    RUBY
  end

  test "no offense for method called in block" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            included do
              helper_method
            end

            def run; end

            def helper_method; end
          end
      end
    RUBY
  end
end
