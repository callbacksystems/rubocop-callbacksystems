require "test_helper"

class RuboCop::Cop::Callbacksystems::MethodInvocationOrderTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::MethodInvocationOrder

  test "registers offense when callee is defined before caller" do
    assert_offense <<~RUBY
      class Example
        def helper
        end

        def process
          helper
        end
      end
    RUBY
  end

  test "allows callee defined after caller" do
    assert_no_offense <<~RUBY
      class Example
        def process
          helper
        end

        def helper
        end
      end
    RUBY
  end

  test "allows independent methods in any order" do
    assert_no_offense <<~RUBY
      class Example
        def method_a
        end

        def method_b
        end
      end
    RUBY
  end

  test "handles multiple callees" do
    assert_no_offense <<~RUBY
      class Example
        def process
          helper_1
          helper_2
        end

        def helper_1
        end

        def helper_2
        end
      end
    RUBY
  end

  test "registers offense for multiple callees in wrong order" do
    assert_offense <<~RUBY
      class Example
        def helper_1
        end

        def process
          helper_1
          helper_2
        end

        def helper_2
        end
      end
    RUBY
  end

  test "handles chained calls" do
    assert_no_offense <<~RUBY
      class Example
        def process
          step_1
        end

        def step_1
          step_2
        end

        def step_2
        end
      end
    RUBY
  end

  test "registers offense for nested callee in wrong position" do
    assert_offense <<~RUBY
      class Example
        def nested
        end

        def process
          step_1
        end

        def step_1
          nested
        end
      end
    RUBY
  end

  test "works with private methods" do
    assert_no_offense <<~RUBY
      class Example
        def process
          helper
        end

        private
          def helper
          end
      end
    RUBY
  end

  test "works in modules" do
    assert_no_offense <<~RUBY
      module Example
        def process
          helper
        end

        def helper
        end
      end
    RUBY
  end

  test "ignores calls to methods not defined in the class" do
    assert_no_offense <<~RUBY
      class Example
        def process
          external_method
          puts "hello"
        end
      end
    RUBY
  end

  test "ignores calls with explicit receivers" do
    assert_no_offense <<~RUBY
      class Example
        def helper
        end

        def process
          other.helper
        end
      end
    RUBY
  end

  test "handles class methods in class << self" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          def process
            helper
          end

          def helper
          end
        end
      end
    RUBY
  end

  test "handles single method class" do
    assert_no_offense <<~RUBY
      class Example
        def process
        end
      end
    RUBY
  end

  test "handles empty class" do
    assert_no_offense <<~RUBY
      class Example
      end
    RUBY
  end

  test "allows method referenced by delegate to: to be defined anywhere" do
    assert_no_offense <<~RUBY
      class Source
        delegate :present?, to: :object

        def prefix
          case stamp.prefix
          when false then nil
          when nil then inferred_prefix
          else stamp.prefix
          end
        end

        private
          def object
            @object ||= record.send(stamp.from)
          end

          def inferred_prefix
            object.model_name.element
          end
      end
    RUBY
  end

  test "allows method referenced by callback symbol" do
    assert_no_offense <<~RUBY
      class Order
        after_commit :notify_later

        def process
          notify_later
        end

        def notify_later
          NotifyJob.perform_later(self)
        end
      end
    RUBY
  end

  test "allows method referenced in lambda callback" do
    assert_no_offense <<~RUBY
      class Order
        before_action -> { load_order }

        def process
          load_order
        end

        def load_order
          @order = Order.find(params[:id])
        end
      end
    RUBY
  end

  test "allows method referenced in if: option" do
    assert_no_offense <<~RUBY
      class Order
        before_action :load_order, if: :order_present?

        def process
          order_present?
        end

        def load_order
        end

        def order_present?
          params[:order_id].present?
        end
      end
    RUBY
  end

  test "allows method referenced in unless: option" do
    assert_no_offense <<~RUBY
      class Order
        before_action :load_order, unless: :skip_loading?

        def process
          skip_loading?
        end

        def load_order
        end

        def skip_loading?
          request.format.json?
        end
      end
    RUBY
  end

  test "allows method referenced in lambda if: option" do
    assert_no_offense <<~RUBY
      class Order
        before_action :load_order, if: -> { should_load? }

        def process
          should_load?
        end

        def load_order
        end

        def should_load?
          true
        end
      end
    RUBY
  end

  test "allows private method to call public method defined above" do
    assert_no_offense <<~RUBY
      class Trial
        def active?
          ends_at > Time.current
        end

        private
          def days_remaining
            return 0 unless active?

            (ends_at - Time.current).to_i
          end
      end
    RUBY
  end

  test "allows multiple private methods to call same public method" do
    assert_no_offense <<~RUBY
      class Trial
        def active?
          true
        end

        private
          def days_remaining
            active? ? 10 : 0
          end

          def status
            active? ? :active : :expired
          end
      end
    RUBY
  end

  test "still registers offense for private method calling private method out of order" do
    assert_offense <<~RUBY
      class Example
        private
          def helper
          end

          def process
            helper
          end
      end
    RUBY
  end

  test "still registers offense for public method calling public method out of order" do
    assert_offense <<~RUBY
      class Example
        def helper
        end

        def process
          helper
        end
      end
    RUBY
  end

  test "nested class methods are analyzed independently from outer class" do
    assert_no_offense <<~RUBY
      class Outer
        def process
          helper
        end

        def helper
        end

        private
          class Inner
            def inner_process
              inner_helper
            end

            def inner_helper
            end
          end
      end
    RUBY
  end

  test "does not consider methods from nested class as callees" do
    assert_no_offense <<~RUBY
      class Outer
        def process
          helper
        end

        private
          class Inner
            def helper
            end
          end
      end
    RUBY
  end

  test "registers offense in nested class for wrong order" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def helper
            end

            def process
              helper
            end
          end
      end
    RUBY
  end

  test "nested class methods do not affect outer class ordering" do
    assert_no_offense <<~RUBY
      class Outer
        def process
          outer_helper
        end

        def outer_helper
        end

        private
          class Inner
            def outer_helper
            end

            def inner_process
            end
          end
      end
    RUBY
  end
end
