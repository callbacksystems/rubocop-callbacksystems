require "test_helper"

class RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoEachWithEarlyReturn

  test "allows a return that stands outside any conditional" do
    assert_no_offense <<~RUBY
      def process
        items.each do |item|
          return item
        end
      end
    RUBY
  end

  test "allows an each block with no body" do
    assert_no_offense <<~RUBY
      items.each do |item|
      end
    RUBY
  end

  test "registers offense for each with return if" do
    assert_offense <<~RUBY
      items.each do |item|
        return item if item.valid?
      end
    RUBY
  end

  test "registers offense for each with return unless" do
    assert_offense <<~RUBY
      items.each do |item|
        return item unless item.invalid?
      end
    RUBY
  end

  test "registers offense in method context" do
    assert_offense <<~RUBY
      def find_valid
        items.each do |item|
          return item if item.valid?
        end
        nil
      end
    RUBY
  end

  test "registers offense for a non-local return inside an ordinary nested block" do
    assert_offense <<~RUBY
      def find_valid
        items.each do |item|
          transaction do
            return item if item.valid?
          end
        end
      end
    RUBY
  end

  test "allows a nested block return of an argument shadowing the each argument" do
    assert_no_offense <<~RUBY
      def find_valid
        items.each do |item|
          candidates.then do |item|
            return item if item.valid?
          end
        end
      end
    RUBY
  end

  test "allows conditional returns owned by deferred callable blocks" do
    assert_no_offense <<~RUBY
      def find_valid
        items.each do |item|
          -> { return item if item.valid? }
          lambda { return item if item.valid? }
          proc { return item if item.valid? }
          Proc.new { return item if item.valid? }
          define_method(:callback) { return item if item.valid? }
        end
      end
    RUBY
  end

  test "allows conditional returns owned by nested method definitions" do
    assert_no_offense <<~RUBY
      def find_valid
        items.each do |item|
          def callback(item)
            return item if item.valid?
          end

          def self.other_callback(item)
            return item if item.valid?
          end
        end
      end
    RUBY
  end

  test "registers returns in definition headers evaluated by the each block" do
    assert_offense <<~RUBY, count: 2
      items.each do |item|
        class Match < (return item if item.valid?)
        end
      end

      items.each do |item|
        class << (return item if item.valid?)
        end
      end
    RUBY
  end

  test "registers offenses for numbered and implicit it block arguments" do
    assert_offense <<~RUBY, count: 2
      items.each { return _1 if _1.valid? }
      items.each { return it if it.valid? }
    RUBY
  end

  test "allows a conditional return of a transformed value" do
    assert_no_offense <<~RUBY
      def find_valid
        items.each do |item|
          return decorate(item) if item.valid?
        end
      end
    RUBY
  end

  test "allows a conditional return with no value" do
    assert_no_offense <<~RUBY
      items.each do |item|
        return if item.valid?
      end
    RUBY
  end

  test "allows find instead of each with return" do
    assert_no_offense <<~RUBY
      items.find { it.valid? }
    RUBY
  end

  test "allows each without return" do
    assert_no_offense <<~RUBY
      items.each do |item|
        process(item)
      end
    RUBY
  end

  test "allows each with unconditional return" do
    assert_no_offense <<~RUBY
      items.each do |item|
        process(item)
        return item
      end
    RUBY
  end

  test "allows detect instead of each" do
    assert_no_offense <<~RUBY
      items.detect { it.valid? }
    RUBY
  end
end
