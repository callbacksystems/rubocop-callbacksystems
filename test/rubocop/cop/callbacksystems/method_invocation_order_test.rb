require "test_helper"

class RuboCop::Cop::Callbacksystems::MethodInvocationOrderTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::MethodInvocationOrder

  ACTION_ORDER = {
    "Rails/ActionOrder" => { "Enabled" => true, "ExpectedOrder" => %w[ index show new create edit update destroy ] }
  }
  NO_ACTION_ORDER = { "Rails/ActionOrder" => { "Enabled" => false } }

  test "keeps the methods of a protected section in the order" do
    assert_no_offense <<~RUBY
      class Example
        def process
          helper
        end

        protected
          def helper
          end
      end
    RUBY
  end

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

  test "moves the last method of a run together with the comment trailing it" do
    assert_correction <<~BAD, <<~GOOD
      class Example
        def helper
        end # shared by both

        def process
          helper
        end
      end
    BAD
      class Example
        def process
          helper
        end

        def helper
        end # shared by both
      end
    GOOD
  end

  test "autocorrects by moving the caller before the callee" do
    assert_correction <<~BAD, <<~GOOD
      class Example
        def helper
        end

        def process
          helper
        end
      end
    BAD
      class Example
        def process
          helper
        end

        def helper
        end
      end
    GOOD
  end

  test "reports without moving a method whose tooling directive would change scope" do
    assert_uncorrectable_offense <<~RUBY
      class Example
        def helper
        end

        # :nocov:
        def process
          helper
        end
        # :nocov:
      end
    RUBY
  end

  test "registers offense when sibling callees are defined out of invocation order" do
    assert_offense <<~RUBY
      class Example
        def process
          helper_b
          helper_a
        end

        def helper_a
        end

        def helper_b
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

  test "registers and autocorrects class methods inside class << self" do
    assert_correction <<~BAD, <<~GOOD
      class Example
        class << self
          def helper
          end

          def process
            helper
          end
        end
      end
    BAD
      class Example
        class << self
          def process
            helper
          end

          def helper
          end
        end
      end
    GOOD
  end

  test "analyzes instance and singleton method visibility independently" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          private
            def inherited(subclass)
              super
            end
        end

        def initialize
        end
      end
    RUBY
  end

  test "registers and autocorrects direct singleton method definitions" do
    assert_correction <<~BAD, <<~GOOD
      class Example
        def self.helper
        end

        def self.process
          helper
        end
      end
    BAD
      class Example
        def self.process
          helper
        end

        def self.helper
        end
      end
    GOOD
  end

  test "does not treat a singleton method as an instance method callee" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          def helper
          end
        end

        def process
          helper
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

  test "leaves repeated method definitions in their written order" do
    source = <<~RUBY
      class Example
        def helper
        end

        def process
          helper
        end

        def helper
          super
        end
      end
    RUBY

    assert_no_offense source
    assert_no_correction source
  end

  test "reports without ordering methods across an independent comment" do
    assert_uncorrectable_offense <<~RUBY
      class Example
        def helper
        end

        # Public entry points.

        def process
          helper
        end
      end
    RUBY
  end

  test "orders a delegate target after the method that really calls it" do
    assert_correction <<~BAD, <<~GOOD
      class Source
        delegate :present?, to: :object

        def prefix
          inferred_prefix
        end

        private
          def object
            @object ||= record.send(stamp.from)
          end

          def inferred_prefix
            object.model_name.element
          end
      end
    BAD
      class Source
        delegate :present?, to: :object

        def prefix
          inferred_prefix
        end

        private
          def inferred_prefix
            object.model_name.element
          end

          def object
            @object ||= record.send(stamp.from)
          end
      end
    GOOD
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

  test "a callback method leads its group; its macro calls it from the top" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        after_commit :deliver

        def generate
          format
        end

        def format
        end

        def deliver
        end
      end
    BAD
      class Report
        after_commit :deliver

        def deliver
        end

        def generate
          format
        end

        def format
        end
      end
    GOOD
  end

  test "a guard is ordered before the action it guards" do
    assert_correction <<~BAD, <<~GOOD
      class Order
        before_save :normalize, unless: :skip?

        def normalize
        end

        def skip?
        end
      end
    BAD
      class Order
        before_save :normalize, unless: :skip?

        def skip?
        end

        def normalize
        end
      end
    GOOD
  end

  test "a lambda guard leads like a symbol guard" do
    assert_correction <<~BAD, <<~GOOD
      class Order
        before_save :normalize, if: -> { changed? }

        def normalize
        end

        def changed?
        end
      end
    BAD
      class Order
        before_save :normalize, if: -> { changed? }

        def changed?
        end

        def normalize
        end
      end
    GOOD
  end

  test "callback methods lead in guard-then-action order per concern" do
    assert_correction <<~BAD, <<~GOOD
      class Event
        after_update :notify_time, if: :should_notify_time?
        after_update :notify_status, if: :should_notify_status?

        private
          def should_notify_time?
            saved_change_to_starts_at?
          end

          def should_notify_status?
            saved_change_to_status?
          end

          def notify_time
            deliver(:time)
          end

          def notify_status
            deliver(:status)
          end
      end
    BAD
      class Event
        after_update :notify_time, if: :should_notify_time?
        after_update :notify_status, if: :should_notify_status?

        private
          def should_notify_time?
            saved_change_to_starts_at?
          end

          def notify_time
            deliver(:time)
          end

          def should_notify_status?
            saved_change_to_status?
          end

          def notify_status
            deliver(:status)
          end
      end
    GOOD
  end

  test "a macro-referenced method a def calls follows that caller, not the macro" do
    assert_correction <<~BAD, <<~GOOD
      class Order
        after_commit :sync

        def sync
        end

        def process
          sync
        end
      end
    BAD
      class Order
        after_commit :sync

        def process
          sync
        end

        def sync
        end
      end
    GOOD
  end

  test "a delegation target leads like any macro reference" do
    assert_no_offense <<~RUBY
      class Collection
        delegate_missing_to :items

        def items
          @items ||= build
        end

        def build
          []
        end
      end
    RUBY
  end

  test "a callback method leads its group over what the constructor calls" do
    assert_offense <<~RUBY
      class Order
        after_commit :notify

        def initialize(record)
          @record = record
          prepare
        end

        private
          def prepare
          end

          def notify
          end
      end
    RUBY
  end

  test "a macro-referenced method leads its group over what the constructor calls" do
    assert_offense <<~RUBY
      class Graph
        delegate :each, to: :components

        def initialize(names)
          @names = names
          link(names)
        end

        private
          def link(names)
          end

          def components
          end
      end
    RUBY
  end

  test "the constructor leads a macro-referenced method, the order Layout/ClassStructure also asks for" do
    assert_no_offense <<~RUBY
      class Statement
        delegate :source, to: :range

        def initialize(node)
          @node = node
        end

        def range
          @node.source_range
        end
      end
    RUBY
  end

  test "a private callback leads within the private section" do
    assert_correction <<~BAD, <<~GOOD
      class Order
        after_commit :notify

        def total
          compute
        end

        private
          def compute
          end

          def notify
          end
      end
    BAD
      class Order
        after_commit :notify

        def total
          compute
        end

        private
          def notify
          end

          def compute
          end
      end
    GOOD
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

  test "a protected caller does not place the public methods it calls" do
    assert_no_offense <<~RUBY
      class Trial
        def active?
          true
        end

        def ends_at
          Time.current
        end

        protected
          def days_remaining
            [ ends_at, active? ]
          end
      end
    RUBY
  end

  test "a private callback calling a public method leaves that method after its public caller" do
    assert_correction <<~BAD, <<~GOOD
      class Account
        validate :currency_must_be_locked

        def merchant
        end

        def enabled?
          merchant.connected?
        end

        private
          def currency_must_be_locked
            merchant.currency
          end
      end
    BAD
      class Account
        validate :currency_must_be_locked

        def enabled?
          merchant.connected?
        end

        def merchant
        end

        private
          def currency_must_be_locked
            merchant.currency
          end
      end
    GOOD
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

  test "does not treat block_pass references as calls on self" do
    assert_no_offense <<~RUBY
      class Example
        def transform
        end

        def process(items)
          items.each(&:transform)
        end
      end
    RUBY
  end

  test "computes visibilities per class instead of memoizing across the file" do
    assert_equal 2, assert_offense(<<~RUBY).size, "Both classes should report the same out-of-order call"
      class A
        private
          def helper
          end

        public

        def main
          helper
        end
      end

      class B
        private
          def main
          end

        public

        def helper
          main
        end
      end
    RUBY
  end
  test "leaves a controller action a macro names where Rails/ActionOrder wants it" do
    assert_no_offense <<~RUBY, file: "app/controllers/sessions_controller.rb", config: ACTION_ORDER
      class SessionsController < ApplicationController
        rate_limit :create, to: 10, within: 30.minutes

        def new
        end

        def create
        end
      end
    RUBY
  end

  test "orders controller actions as Rails/ActionOrder asks, not by first invocation" do
    offenses = assert_offense <<~RUBY, file: "app/controllers/widgets_controller.rb", config: ACTION_ORDER
      class WidgetsController < ApplicationController
        def create
        end

        def index
        end
      end
    RUBY

    assert_includes offenses.first.message, "Method `index` should be defined before `create`"
  end

  test "still orders the private methods of a controller by invocation" do
    offenses = assert_offense <<~RUBY, file: "app/controllers/widgets_controller.rb", config: ACTION_ORDER
      class WidgetsController < ApplicationController
        def index
          load_widgets
        end

        private
          def scope
          end

          def load_widgets
            scope
          end
      end
    RUBY

    assert_includes offenses.first.message, "Method `load_widgets` should be defined before `scope`"
  end

  test "orders a plain class by invocation, since no action order applies" do
    offenses = assert_offense <<~RUBY, config: ACTION_ORDER
      class Widget
        def create
        end

        def index
          create
        end
      end
    RUBY

    assert_includes offenses.first.message, "Method `index` should be defined before `create`"
  end

  test "orders controller actions by first invocation when Rails/ActionOrder is off" do
    offenses = assert_offense <<~RUBY, file: "app/controllers/widgets_controller.rb", config: NO_ACTION_ORDER
      class WidgetsController < ApplicationController
        def index
        end

        def create
          index
        end
      end
    RUBY

    assert_includes offenses.first.message, "Method `create` should be defined before `index`"
  end
end
