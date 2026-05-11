require "test_helper"

class EarlyReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EarlyReturn

  test "allows single guard clause on first line with return unless" do
    assert_no_offense(<<~RUBY)
      def process(user)
        return unless user
        do_something(user)
      end
    RUBY
  end

  test "allows single guard clause on first line with return if" do
    assert_no_offense(<<~RUBY)
      def process(user)
        return if user.nil?
        do_something(user)
      end
    RUBY
  end

  test "allows method without early returns" do
    assert_no_offense(<<~RUBY)
      def process(user)
        if user
          do_something(user)
        end
      end
    RUBY
  end

  test "allows method with only final return" do
    assert_no_offense(<<~RUBY)
      def calculate(x)
        result = x * 2
        result
      end
    RUBY
  end

  test "registers offense for return in middle of method" do
    assert_offense(<<~RUBY)
      def process(user)
        data = fetch_data
        return if data.empty?
        process_data(data)
      end
    RUBY
  end

  test "registers offense for multiple early returns" do
    offenses = assert_offense(<<~RUBY)
      def process(user)
        return unless user
        return if user.inactive?
        do_something
      end
    RUBY
    assert_equal 1, offenses.size
  end

  test "registers offense for return after first statement even if guard-like" do
    assert_offense(<<~RUBY)
      def process(user)
        log_call
        return unless user
        do_something
      end
    RUBY
  end

  test "allows guard clause in class methods" do
    assert_no_offense(<<~RUBY)
      def self.find(id)
        return unless id
        where(id: id).first
      end
    RUBY
  end

  test "registers offense for return inside if block that is not first line" do
    assert_offense(<<~RUBY)
      def process(data)
        result = []
        if data.present?
          return result if data.empty?
          result = process_data(data)
        end
        result
      end
    RUBY
  end

  test "allows guard clause on first line in method with rescue" do
    assert_no_offense(<<~RUBY)
      def update_api_record(**attributes)
        return unless processor_id?

        find_record.tap { |r| r.update(**attributes) }
      rescue ActiveRecord::RecordNotFound
        update! processor_id: nil
      end
    RUBY
  end

  test "allows guard clause on first line in method with ensure" do
    assert_no_offense(<<~RUBY)
      def process(user)
        return unless user
        do_something(user)
      ensure
        cleanup
      end
    RUBY
  end

  test "allows guard clause on first line in method with rescue and ensure" do
    assert_no_offense(<<~RUBY)
      def process(user)
        return unless user
        do_something(user)
      rescue StandardError
        handle_error
      ensure
        cleanup
      end
    RUBY
  end

  test "registers offense for non-first-line return in method with rescue" do
    assert_offense(<<~RUBY)
      def process(data)
        log_call
        return if data.empty?
        process_data(data)
      rescue StandardError
        handle_error
      end
    RUBY
  end

  test "allows next guard on first line of block" do
    assert_no_offense(<<~RUBY)
      def process(items)
        return if items.empty?
        items.each do |item|
          next if item.invalid?
          process_item(item)
        end
      end
    RUBY
  end

  test "allows break guard on first line of block" do
    assert_no_offense(<<~RUBY)
      def process(items)
        items.each do |item|
          break if item.last?
          process_item(item)
        end
      end
    RUBY
  end

  test "registers offense for next in middle of block" do
    assert_offense(<<~RUBY)
      items.each do |item|
        process(item)
        next if item.done?
        finalize(item)
      end
    RUBY
  end

  test "registers offense for break in middle of block" do
    assert_offense(<<~RUBY)
      items.each do |item|
        process(item)
        break if item.last?
      end
    RUBY
  end

  test "registers offense for multiple next in block" do
    assert_offense(<<~RUBY)
      items.each do |item|
        next if item.nil?
        next if item.invalid?
        process(item)
      end
    RUBY
  end

  test "registers offense for return inside a block" do
    assert_offense(<<~RUBY)
      def process(items)
        items.reduce(0) do |count, item|
          return :done if item.finished?
          count + 1
        end
      end
    RUBY
  end

  test "allows return inside a lambda" do
    assert_no_offense(<<~RUBY)
      def process
        validator = lambda { |x| return false unless x.valid?; true }
        validator.call(input)
      end
    RUBY
  end

  test "next in nested block does not affect outer block" do
    assert_no_offense(<<~RUBY)
      items.each do |item|
        item.parts.each do |part|
          next if part.nil?
          process(part)
        end
      end
    RUBY
  end

  test "allows break anywhere inside loop do block" do
    assert_no_offense(<<~RUBY)
      loop do
        data = fetch
        break if data.nil?
        process(data)
      end
    RUBY
  end

  test "allows break anywhere inside method named loop with receiver" do
    assert_no_offense(<<~RUBY)
      ssh.loop do |channel|
        channel.read
        break unless channel.active?
        channel.process
      end
    RUBY
  end

  test "allows return inside a loop block of a method" do
    assert_no_offense(<<~RUBY)
      def find_active
        loop do
          item = next_item
          return item if item.active?
        end
      end
    RUBY
  end
end
