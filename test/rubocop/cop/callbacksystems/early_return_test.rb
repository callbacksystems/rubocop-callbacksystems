require "test_helper"

class EarlyReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EarlyReturn

  test "reads a method opening with an empty begin block" do
    assert_offense <<~RUBY
      def process
        begin
        end

        return if done?
      end
    RUBY
  end

  test "reads an if whose only branch is an else that exits" do
    assert_offense <<~RUBY
      def process
        if ready?
        else
          return
        end

        return if done?
      end
    RUBY
  end

  test "reads an unless that opens a method holding an exit elsewhere" do
    assert_offense <<~RUBY
      def process
        unless ready?
          deliver
        end

        return if done?
      end
    RUBY
  end

  test "reads an if that opens a method holding an exit elsewhere" do
    assert_offense <<~RUBY
      def process
        if ready?
          deliver
        end

        return if done?
      end
    RUBY
  end

  test "allows an unless that is not a guard as the first statement" do
    assert_no_offense <<~RUBY
      def process
        unless ready?
          deliver
        end
      end
    RUBY
  end

  test "allows an if with both branches as the first statement" do
    assert_no_offense <<~RUBY
      def process
        if ready?
          deliver
        else
          wait
        end
      end
    RUBY
  end

  test "allows a method with no body" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "allows a one-armed if that is not a guard" do
    assert_no_offense <<~RUBY
      def process
        if ready?
          deliver
        end
      end
    RUBY
  end

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
    assert_offense(<<~RUBY, count: 1)
      def process(user)
        return unless user
        return if user.inactive?
        do_something
      end
    RUBY
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

  test "registers offense for return inside a case branch" do
    assert_offense <<~RUBY
      def process(status)
        log(status)
        case status
        when :done then return
        end
        finish
      end
    RUBY
  end

  test "registers offense for return inside a pattern matching branch" do
    assert_offense <<~RUBY
      def process(status)
        log(status)
        case status
        in :done then return
        end
        finish
      end
    RUBY
  end

  test "registers offense for return inside a while loop" do
    assert_offense <<~RUBY
      def process
        while pending?
          return result if ready?
        end
      end
    RUBY
  end

  test "registers returns in conditional subjects and branch conditions" do
    assert_offense <<~RUBY, count: 3
      def process(value)
        if ready? || return
          finish
        end

        case value || return
        when :ready then finish
        end

        case value
        when ready? || return then finish
        end
      end
    RUBY
  end

  test "registers a return in a pattern guard" do
    assert_offense <<~RUBY
      def process(value)
        case value
        in Integer if ready? || return then finish
        end
      end
    RUBY
  end

  test "registers offense for return inside a call argument" do
    assert_offense <<~RUBY
      def process
        publish(result || return)
      end
    RUBY
  end

  test "registers a return in arguments evaluated before an immediate block" do
    assert_offense <<~RUBY
      def process(result)
        consume(result || return) { finish }
      end
    RUBY
  end

  test "registers a next in arguments evaluated before a nested block" do
    assert_offense <<~RUBY
      items.each do |item|
        consume(item || next) { finish }
      end
    RUBY
  end

  test "does not take exits belonging to nested language loops from the surrounding block" do
    assert_no_offense <<~RUBY
      items.each do |item|
        while item.pending?
          break if item.finished?
        end

        until item.ready?
          next if item.cancelled?
        end

        for entry in item.entries
          break if entry.last?
        end
      end
    RUBY
  end

  test "registers exits in a collection evaluated before a nested for loop" do
    assert_offense <<~RUBY, count: 2
      items.each do |item|
        prepare(item)

        for entry in (item.entries || next)
          process(entry)
        end

        for entry in (item.fallbacks || break)
          process(entry)
        end
      end
    RUBY
  end

  test "does not read a return in a nested method" do
    assert_no_offense <<~RUBY
      def process
        helper = Class.new do
          def call
            return if ready?
          end
        end
        helper.new.call
      end
    RUBY
  end

  test "registers returns in receivers evaluated while defining methods and singleton classes" do
    assert_offense <<~RUBY, count: 2
      def install(target)
        def (target || return).run; end

        class << (target || return)
        end

        finish
      end
    RUBY
  end

  test "registers exits in class identifiers and superclasses evaluated from a block" do
    assert_offense <<~RUBY, count: 2
      items.each do |item|
        prepare

        class (item.namespace || next)::Worker
        end

        class SpecializedWorker < (item.base || next)
        end
      end
    RUBY
  end

  test "does not read a return captured by deferred callable blocks" do
    assert_no_offense <<~RUBY
      def process
        proc { return }
        Proc.new { return }
        define_method(:later) { return }
        define_singleton_method(:other) { return }
        finish
      end
    RUBY
  end

  test "reads a method whose body is only a rescue clause" do
    assert_offense <<~RUBY
      def process
      rescue Timeout::Error
        log
        return if retried?
        retry_later
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

  test "registers offense for non-first-line return in method with ensure" do
    assert_offense <<~RUBY
      def process
        return if done?
        work
        return early if quick?
        finish
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

  test "yields an each search return to NoEachWithEarlyReturn" do
    assert_no_offense <<~RUBY
      def find_valid
        items.each do |item|
          return item if item.valid?
        end
      end
    RUBY
  end

  test "keeps transformed and valueless each returns" do
    assert_offense <<~RUBY, count: 2
      def find_valid
        items.each do |item|
          return decorate(item) if item.valid?
          return if item.finished?
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

  test "allows a conditional whose branch holds nothing" do
    assert_no_offense <<~RUBY
      class Report
        def render
          if ready?
          end
        end
      end
    RUBY
  end

  test "reads exits nested deeper than Ruby's call stack" do
    returned = RuboCop::AST::Node.new(:return)
    body = 2_000.times.reduce(returned) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }
    exits = RuboCop::Cop::Callbacksystems::EarlyReturn::BodyExits.new(body, :return, walk_blocks: true)

    assert_equal [ returned ], exits.each.to_a
  end
end
