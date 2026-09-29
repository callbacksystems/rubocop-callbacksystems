require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferMethodOverLambdaTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferMethodOverLambda

  test "registers offense for a stabby lambda that captures nothing, without a fix" do
    offenses = assert_uncorrectable_offense <<~RUBY
      def total(orders)
        price_of = ->(order) { order.quantity * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY

    assert_includes offenses.first.message, "`price_of` captures nothing from `total`, so it can be a method of its own"
  end

  test "registers offense for a lambda block" do
    assert_offense <<~RUBY
      def total(orders)
        price_of = lambda { |order| order.quantity * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "registers offense for a proc block" do
    assert_offense <<~RUBY
      def total(orders)
        price_of = proc { |order| order.quantity * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "registers offense for Proc.new" do
    assert_offense <<~RUBY
      def total(orders)
        price_of = Proc.new { |order| order.quantity * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "registers offense for a lambda that reads only an instance variable" do
    assert_offense <<~RUBY
      def total(orders)
        price_of = ->(order) { order.quantity * @unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "registers offense for a lambda that reads only its own parameter" do
    assert_offense <<~RUBY
      def total(orders)
        double = ->(quantity) { quantity * 2 }
        orders.sum { double.call(it.quantity) }
      end
    RUBY
  end

  test "registers offense for a lambda whose own parameter shadows a method parameter" do
    assert_offense <<~RUBY
      def total(order)
        price_of = ->(order) { order.quantity * order.unit_price }
        price_of.call(order)
      end
    RUBY
  end

  test "registers offense for a lambda that reads only its it parameter" do
    assert_offense <<~RUBY
      def total(orders)
        double = -> { it * 2 }
        orders.sum { double.call(it.quantity) }
      end
    RUBY
  end

  test "registers offense for a lambda whose locals are its own" do
    assert_offense <<~RUBY
      def total(orders)
        price_of = ->(order) do
          quantity = order.quantity
          quantity * order.unit_price
        end
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "registers offense for a lambda that only calls itself" do
    assert_offense <<~RUBY
      def depth(node)
        depth_of = ->(current) { current.parent ? depth_of.call(current.parent) + 1 : 0 }
        depth_of.call(node)
      end
    RUBY
  end

  test "registers offense for both a lambda and the one nested inside it when neither captures" do
    offenses = assert_offense <<~RUBY
      def total(orders)
        price_of = ->(order) do
          double = ->(quantity) { quantity * 2 }
          double.call(order.quantity) * order.unit_price
        end
        orders.sum { price_of.call(it) }
      end
    RUBY

    assert_equal %w[ price_of double ], offenses.map { it.message[/`(\w+)` captures/, 1] }
  end

  test "allows a lambda that reads a parameter of the method" do
    assert_no_offense <<~RUBY
      def total(orders, rate)
        price_of = ->(order) { order.quantity * rate }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda that reads a local assigned above it" do
    assert_no_offense <<~RUBY
      def total(orders)
        rate = current_rate
        price_of = ->(order) { order.quantity * rate }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda that reads a parameter of the block holding it" do
    assert_no_offense <<~RUBY
      def total(orders)
        orders.each do |order|
          price_of = -> { order.quantity * order.unit_price }
          price_of.call
        end
      end
    RUBY
  end

  test "allows a lambda that reads a block-local variable" do
    assert_no_offense <<~RUBY
      def total(orders)
        orders.each do |; rate|
          rate = default_rate
          price_of = -> { current_order.quantity * rate }
          price_of.call
        end
      end
    RUBY
  end

  test "allows a lambda that reads a method parameter in a default value" do
    assert_no_offense <<~RUBY
      def total(orders, rate)
        price_of = ->(order, multiplier = rate) { order.quantity * multiplier }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda that reassigns a method local" do
    assert_no_offense <<~RUBY
      def total(orders)
        sum = 0
        add = ->(order) { sum += order.quantity }
        orders.each(&add)
        sum
      end
    RUBY
  end

  test "allows a lambda that reads a local bound by a pattern" do
    assert_no_offense <<~RUBY
      def total
        current_order => { rate: }
        price_of = -> { current_order.quantity * rate }
        price_of.call
      end
    RUBY
  end

  test "allows a lambda that reads locals bound through pattern nesting" do
    assert_no_offense <<~RUBY
      def total
        current_order => { pricing: [Integer => rate, *adjustments] }
        price_of = -> { current_order.quantity * rate + adjustments.sum }
        price_of.call
      end
    RUBY
  end

  test "allows a lambda that reassigns a method local through a pattern" do
    assert_no_offense <<~RUBY
      def total
        rate = default_rate
        price_of = -> { current_order => { rate: } }
        price_of.call
        rate
      end
    RUBY
  end

  test "allows a lambda that reads a pinned method local" do
    assert_no_offense <<~RUBY
      def total
        rate = default_rate
        valid = -> { current_order in { rate: ^rate } }
        valid.call
      end
    RUBY
  end

  test "allows a lambda that reads a named regexp capture" do
    assert_no_offense <<~'RUBY'
      def total(input)
        /rate=(?<rate>\d+)/ =~ input
        calculate = -> { rate.to_i * 2 }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that reassigns a method local through a named regexp capture" do
    assert_no_offense <<~'RUBY'
      def total
        rate = default_rate
        capture = -> { /rate=(?<rate>\d+)/ =~ current_input }
        capture.call
        rate
      end
    RUBY
  end

  test "registers offense when pattern variables belong to the lambda" do
    assert_offense <<~RUBY
      def total
        unpack = -> { current_order => { rate: }; rate * 2 }
        unpack.call
      end
    RUBY
  end

  test "registers offense when a same-named method pattern binding follows the lambda" do
    assert_offense <<~RUBY
      def total
        unpack = -> { current_order => { rate: }; rate * 2 }
        current_order => { rate: }
        unpack.call
      end
    RUBY
  end

  test "registers offense when a named regexp capture belongs to the lambda" do
    assert_offense <<~'RUBY'
      def total
        capture = -> { /rate=(?<rate>\d+)/ =~ current_input; rate.to_i }
        capture.call
      end
    RUBY
  end

  test "registers offense when a same-named regexp capture follows the lambda" do
    assert_offense <<~'RUBY'
      def total
        capture = -> { /rate=(?<rate>\d+)/ =~ current_input; rate.to_i }
        /rate=(?<rate>\d+)/ =~ current_input
        capture.call
      end
    RUBY
  end

  test "allows a lambda nested inside a lambda when it reads the outer parameter" do
    offenses = assert_offense <<~RUBY, count: 1
      def total(orders)
        price_of = ->(order) do
          double = -> { order.quantity * 2 }
          double.call * order.unit_price
        end
        orders.sum { price_of.call(it) }
      end
    RUBY

    assert_includes offenses.first.message, "`price_of` captures nothing from `total`"
  end

  test "registers offense for a lambda that reads only its numbered parameter" do
    assert_offense <<~RUBY
      def total(orders)
        double = -> { _1 * 2 }
        orders.sum { double.call(it.quantity) }
      end
    RUBY
  end

  test "registers offense when a matching local is assigned after the lambda" do
    assert_offense <<~RUBY
      def total
        calculate = -> { rate(current_order) }
        rate = default_rate
        calculate.call
      end
    RUBY
  end

  test "registers offense when a same-named assignment follows a lambda assignment" do
    assert_offense <<~RUBY
      def total
        calculate = -> { rate = default_rate; rate * 2 }
        rate = default_rate
        calculate.call
      end
    RUBY
  end

  test "registers offense when a matching local belongs to a nested method" do
    assert_offense <<~RUBY
      def total
        def rate
          rate = default_rate
        end

        calculate = -> { rate(current_order) }
        calculate.call
      end
    RUBY
  end

  test "registers offense when a same-named assignment belongs to a nested method" do
    assert_offense <<~RUBY
      def total
        def configure
          rate = default_rate
        end

        calculate = -> { rate = default_rate; rate * 2 }
        calculate.call
      end
    RUBY
  end

  test "registers offense when a same-named assignment belongs to a sibling block" do
    assert_offense <<~RUBY
      def total
        orders.each { rate = default_rate }
        calculate = -> { rate = default_rate; rate * 2 }
        calculate.call
      end
    RUBY
  end

  test "registers offense when a nested block shadows the method binding" do
    assert_offense <<~RUBY
      def total(rate)
        calculate = -> { orders.map { |rate| rate * 2 } }
        calculate.call
      end
    RUBY
  end

  test "registers offense when the lambda declares a same-named block local" do
    assert_offense <<~RUBY
      def total(rate)
        calculate = lambda { |; rate| rate = default_rate; rate * 2 }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that captures a block-local pattern binding" do
    assert_no_offense <<~RUBY
      def total(orders)
        orders.each do |order|
          order => { rate: }
          calculate = -> { rate * 2 }
          calculate.call
        end
      end
    RUBY
  end

  test "allows a lambda that yields to the method's block" do
    assert_no_offense <<~RUBY
      def total(orders)
        price_of = ->(order) { yield(order) * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda that calls super" do
    assert_no_offense <<~RUBY
      def total(orders)
        price_of = ->(order) { super(order) * 2 }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda that observes the method block" do
    assert_no_offense <<~RUBY
      def callback
        available = -> { block_given? }
        available.call
      end
    RUBY
  end

  test "allows a lambda that observes the method block through explicit self" do
    assert_no_offense <<~RUBY
      def callback
        available = -> { self&.block_given? }
        available.call
      end
    RUBY
  end

  test "allows a lambda that evaluates code in the method binding" do
    assert_no_offense <<~RUBY
      def callback
        rate = default_rate
        calculate = -> { eval("rate * 2") }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that evaluates code through Kernel in the method binding" do
    assert_no_offense <<~RUBY
      def callback
        rate = default_rate
        calculate = -> { Kernel.eval("rate * 2") }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that invokes eval reflectively in the method binding" do
    assert_no_offense <<~RUBY
      def callback
        rate = default_rate
        calculate = -> { send(:eval, "rate * 2") }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that obtains eval reflectively in the method binding" do
    assert_no_offense <<~RUBY
      def callback
        rate = default_rate
        calculate = -> { method("eval").call("rate * 2") }
        calculate.call
      end
    RUBY
  end

  test "allows a lambda that evaluates a string through class_eval in the method binding" do
    assert_no_offense <<~RUBY
      def callback
        rate = default_rate
        calculate = -> { String.class_eval("rate * 2") }
        calculate.call
      end
    RUBY
  end

  test "registers offense for unrelated reflective calls" do
    assert_offense <<~RUBY
      def callback
        invoke = -> { send(:perform) }
        invoke.call
      end
    RUBY
  end

  test "allows a lambda whose dynamic reflective call could reach the method binding" do
    assert_no_offense <<~RUBY
      def callback
        invoke = -> { send(callback_method) }
        invoke.call
      end
    RUBY
  end

  test "registers offense for a reflective call without a method name" do
    assert_offense <<~RUBY
      def callback
        invoke = -> { send }
        invoke.call
      end
    RUBY
  end

  test "registers offense for class_eval with a block that captures nothing" do
    assert_offense <<~RUBY
      def callback
        configure = -> { String.class_eval { perform } }
        configure.call
      end
    RUBY
  end

  test "allows a lambda that observes the method local variables" do
    assert_no_offense <<~RUBY
      def callback
        available = -> { local_variables }
        available.call
      end
    RUBY
  end

  test "allows a proc whose return exits the enclosing method" do
    assert_no_offense <<~RUBY
      def callback
        stop = proc { return :stopped }
        stop.call
      end
    RUBY
  end

  test "allows a lambda at class level" do
    assert_no_offense <<~RUBY
      class Order < ApplicationRecord
        scope :recent, -> { where(created_at: 1.week.ago..) }
        validate -> { errors.add(:base, :empty) if lines.none? }

        RATE = ->(order) { order.quantity * 2 }
      end
    RUBY
  end

  test "allows a lambda held in a local outside a method" do
    assert_no_offense <<~RUBY
      class Order < ApplicationRecord
        recent = -> { where(created_at: 1.week.ago..) }
        scope :recent, recent
      end
    RUBY
  end

  test "allows a lambda held in a top-level local" do
    assert_no_offense <<~RUBY
      callback = -> { perform }
      register(callback)
    RUBY
  end

  test "allows a lambda held in a singleton class body opened by a method" do
    assert_no_offense <<~RUBY
      def configure(target)
        class << target
          callback = -> { perform }
          register(callback)
        end
      end
    RUBY
  end

  test "allows a lambda passed as an argument without a local" do
    assert_no_offense <<~RUBY
      def total(orders)
        orders.sum(&->(order) { order.quantity * order.unit_price })
      end
    RUBY
  end

  test "allows a lambda stored in an instance variable" do
    assert_no_offense <<~RUBY
      def total(orders)
        @price_of ||= ->(order) { order.quantity * order.unit_price }
        orders.sum { @price_of.call(it) }
      end
    RUBY
  end

  test "allows a lambda memoized in a local" do
    assert_no_offense <<~RUBY
      def total(orders)
        price_of ||= ->(order) { order.quantity * order.unit_price }
        orders.sum { price_of.call(it) }
      end
    RUBY
  end

  test "allows a local holding something other than a closure" do
    assert_no_offense <<~RUBY
      def total(orders)
        rate = current_rate
        orders.sum { it.quantity * rate }
      end
    RUBY
  end
end
