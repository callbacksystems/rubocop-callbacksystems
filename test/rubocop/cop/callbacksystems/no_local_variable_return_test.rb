require "test_helper"

class RuboCop::Cop::Callbacksystems::NoLocalVariableReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoLocalVariableReturn

  test "registers offense for returning a local variable" do
    assert_offense <<~RUBY
      def process
        result = calculate_something
        result
      end
    RUBY
  end

  test "registers offense for assign, mutate, return pattern" do
    assert_offense <<~RUBY
      def process
        result = []
        result << item
        result
      end
    RUBY
  end

  test "registers offense for assign, mutate with []=" do
    assert_offense <<~RUBY
      def process
        hash = {}
        hash[:key] = value
        hash
      end
    RUBY
  end

  test "registers offense for explicit return of local variable" do
    assert_offense <<~RUBY
      def build_options
        options = {}
        options.merge!(defaults)
        return options
      end
    RUBY
  end

  test "registers offense for returning local variable from single statement" do
    assert_offense <<~RUBY
      def process
        result = []
        result
      end
    RUBY
  end

  test "registers offense for class method returning local variable" do
    assert_offense <<~RUBY
      def self.build
        items = []
        items << default_item
        items
      end
    RUBY
  end

  test "registers offense for hash with block initialization" do
    assert_offense <<~RUBY
      def collect_usages
        result = Hash.new { |hash, key| hash[key] = [] }
        items.each { |item| result[item.key] << item }
        result
      end
    RUBY
  end

  test "allows tap pattern" do
    assert_no_offense <<~RUBY
      def process
        [].tap do |result|
          result << item
        end
      end
    RUBY
  end

  test "allows each_with_object pattern" do
    assert_no_offense <<~RUBY
      def process
        items.each_with_object([]) do |item, result|
          result << transform(item)
        end
      end
    RUBY
  end

  test "allows then pattern" do
    assert_no_offense <<~RUBY
      def process
        calculate_something.then do |result|
          result.merge(extra: value)
        end
      end
    RUBY
  end

  test "allows returning expression directly" do
    assert_no_offense <<~RUBY
      def process
        calculate_something
      end
    RUBY
  end

  test "allows declarative building" do
    assert_no_offense <<~RUBY
      def process
        [item, other_item]
      end
    RUBY
  end

  test "allows returning method call" do
    assert_no_offense <<~RUBY
      def process
        result = calculate_something
        transform(result)
      end
    RUBY
  end

  test "allows returning literal" do
    assert_no_offense <<~RUBY
      def process
        do_something
        []
      end
    RUBY
  end

  test "allows returning instance variable" do
    assert_no_offense <<~RUBY
      def process
        @result = calculate_something
        @result
      end
    RUBY
  end

  test "allows empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "allows method with only nil" do
    assert_no_offense <<~RUBY
      def process
        nil
      end
    RUBY
  end

  test "inlines an adjacent single-use local variable" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        result = calculate_something
        result
      end
    RUBY
      def process
        calculate_something
      end
    CORRECTED
  end

  test "inlines an explicit return of an adjacent single-use local" do
    assert_correction <<~RUBY, <<~CORRECTED
      def build
        options = compute_options
        return options
      end
    RUBY
      def build
        return compute_options
      end
    CORRECTED
  end

  test "leaves a mutated local untouched for a human to restructure" do
    assert_correction <<~RUBY, <<~SAME
      def process
        result = []
        result << item
        result
      end
    RUBY
      def process
        result = []
        result << item
        result
      end
    SAME
  end

  test "keeps a comment written between the assignment and the returned read" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        def process
          result = calculate_something
          # keep this note
          result
        end
      RUBY
        def process
          # keep this note
          calculate_something
        end
      CORRECTED
  end
end
