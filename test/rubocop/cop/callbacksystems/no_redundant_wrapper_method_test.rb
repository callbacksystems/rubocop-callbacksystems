require "test_helper"

class NoRedundantWrapperMethodTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoRedundantWrapperMethod

  test "registers offense for private method that only wraps another method" do
    offenses = assert_offense <<~RUBY, count: 1
      class Foo
        def all
          find_all
        end

        private
          def find_all
            find(@node)
          end
      end
    RUBY

    assert_includes offenses.first.message, "find_all"
  end

  test "registers offense for private method passing through arguments" do
    assert_offense <<~RUBY, count: 1
      class Foo
        def run(node)
          process(node)
        end

        private
          def process(node)
            analyze(node)
          end
      end
    RUBY
  end

  test "allows public method that wraps" do
    assert_no_offense <<~RUBY
      class Foo
        def authenticated?
          resume_session
        end
      end
    RUBY
  end

  test "allows predicate method that wraps" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def fulfillable?
            paid?
          end
      end
    RUBY
  end

  test "no offense when method chains result" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def find_all
            find(@node).compact
          end
      end
    RUBY
  end

  test "no offense when method transforms arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def process(node)
            analyze(node.children.first)
          end
      end
    RUBY
  end

  test "no offense when method adds arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def process(node)
            analyze(node, default_config)
          end
      end
    RUBY
  end

  test "no offense when method has conditional" do
    assert_no_offense <<~RUBY
      def process(node)
        analyze(node) if node
      end
    RUBY
  end

  test "no offense for empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "registers offense for private method calling with subset of params" do
    assert_offense <<~RUBY, count: 1
      class Foo
        def run(node, config)
          process(node, config)
        end

        private
          def process(node, config)
            analyze(node)
          end
      end
    RUBY
  end
  test "registers offense for a private method that only reads a constant" do
    offenses = assert_offense <<~RUBY
      class Example
        def offense
          Offense.new(message)
        end

        MESSAGE = "Remove this."

        private
          def message
            MESSAGE
          end
      end
    RUBY

    assert_includes offenses.first.message, "Method `message` only wraps `MESSAGE`"
  end

  test "registers offense for a private method reading a namespaced constant of its own name" do
    assert_offense <<~RUBY
      class Example
        def ordered
          levels.reverse
        end

        private
          def levels
            Visibility::LEVELS
          end
      end
    RUBY
  end

  test "allows a private method naming a concept the constant does not" do
    assert_no_offense <<~RUBY
      class Example
        private
          def marker_tag
            DEFAULT_MARKER_TAG
          end
      end
    RUBY
  end

  test "allows a private method whose constant lives under another name" do
    assert_no_offense <<~RUBY
      class Example
        private
          def version
            Formats::Registry::COMPACT
          end
      end
    RUBY
  end

  test "allows a public method that reads a constant" do
    assert_no_offense <<~RUBY
      class Example
        MESSAGE = "Keep this."

        def message
          MESSAGE
        end
      end
    RUBY
  end

  test "allows a predicate that reads a constant" do
    assert_no_offense <<~RUBY
      class Example
        private
          def enabled?
            ENABLED
          end
      end
    RUBY
  end

  test "allows a private method that does something with the constant" do
    assert_no_offense <<~RUBY
      class Example
        private
          def message
            format(MESSAGE, name: name)
          end
      end
    RUBY
  end

  test "allows a private method that takes arguments and reads a constant" do
    assert_no_offense <<~RUBY
      class Example
        private
          def message(name)
            MESSAGE
          end
      end
    RUBY
  end
  test "allows a private method nothing in its class calls, which a superclass or a subclass reaches" do
    assert_no_offense <<~RUBY
      class WidgetsController < ApplicationController
        private
          def path_after_saving
            root_path
          end
      end
    RUBY
  end

  test "allows a private method reading a constant that nothing in its class calls" do
    assert_no_offense <<~RUBY
      class Pixel
        private
          def marker_tag
            MARKER_TAG
          end
      end
    RUBY
  end

  test "registers offense when a sibling private method is the caller" do
    assert_offense <<~RUBY
      class Foo
        private
          def all
            find_all
          end

          def find_all
            find(@node)
          end
      end
    RUBY
  end

  test "allows a private wrapper referenced by a callback macro" do
    assert_no_offense <<~RUBY
      class Foo
        before_save :find_all

        def all
          find_all
        end

        private
          def find_all
            find(@node)
          end
      end
    RUBY
  end

  test "does not borrow a callback reference from outside a constructor block" do
    assert_offense <<~RUBY
      class Outer
        before_save :process

        Handler = Class.new do
          def run
            process(@node)
          end

          private
            def process(node)
              analyze(node)
            end
        end
      end
    RUBY
  end
  test "allows a method taking nothing that several places read" do
    assert_no_offense <<~RUBY
      class Foo
        def names
          scope.pluck(:name)
        end

        def total
          scope.count
        end

        private
          def scope
            account.widgets
          end
      end
    RUBY
  end

  test "allows a method taking nothing that several places read through explicit self" do
    assert_no_offense <<~RUBY
      class Foo
        def names
          scope.pluck(:name)
        end

        def total
          self.scope.count
        end

        private
          def scope
            account.widgets
          end
      end
    RUBY
  end

  test "registers offense for a method with arguments that several places call" do
    assert_offense <<~RUBY
      class Foo
        def one(node)
          process(node)
        end

        def two(node)
          process(node)
        end

        private
          def process(node)
            analyze(node)
          end
      end
    RUBY
  end

  test "allows a constant reader that several places read" do
    assert_no_offense <<~RUBY
      class Foo
        def first
          message
        end

        def second
          message
        end

        private
          def message
            MESSAGE
          end
      end
    RUBY
  end

  test "allows a private method with an empty body" do
    assert_no_offense <<~RUBY
      class Report
        private
          def render
          end
      end
    RUBY
  end

  test "does not take an instance call as a use of a singleton wrapper" do
    assert_no_offense <<~RUBY
      class Report
        def publish
          destination
        end

        class << self
          private
            def destination
              default_destination
            end
        end
      end
    RUBY
  end

  test "does not take a singleton call as a use of an instance wrapper" do
    assert_no_offense <<~RUBY
      class Report
        destination

        private
          def destination
            default_destination
          end
      end
    RUBY
  end
end
