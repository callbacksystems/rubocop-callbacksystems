require "test_helper"

class RuboCop::Cop::Callbacksystems::NoManualAccumulationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoManualAccumulation

  test "registers offense for array accumulation with each" do
    assert_offense <<~RUBY
      def names
        results = []
        items.each { |x| results << x.name }
        results
      end
    RUBY
  end

  test "registers offense for hash accumulation with each" do
    assert_offense <<~RUBY
      def index
        hash = {}
        items.each { |x| hash[x.id] = x }
        hash
      end
    RUBY
  end

  test "registers offense for array accumulation with push" do
    assert_offense <<~RUBY
      def names
        results = []
        items.each { |x| results.push(x.name) }
        results
      end
    RUBY
  end

  test "allows map instead of manual accumulation" do
    assert_no_offense <<~RUBY
      def names
        items.map { it.name }
      end
    RUBY
  end

  test "allows index_by instead of manual hash building" do
    assert_no_offense <<~RUBY
      def index
        items.index_by { it.id }
      end
    RUBY
  end

  test "allows accumulator when not returned" do
    assert_no_offense <<~RUBY
      def process
        results = []
        items.each { |x| results << x.name }
        do_something(results)
      end
    RUBY
  end

  test "allows empty array assigned but not used with each" do
    assert_no_offense <<~RUBY
      def process
        results = []
        results << compute_something
        results
      end
    RUBY
  end

  test "allows each with a side effect besides the mutation" do
    assert_no_offense <<~RUBY
      def names
        results = []
        items.each { |x| log(x); results << x.name }
        results
      end
    RUBY
  end

  test "registers offense for a guarded mutation in each" do
    assert_offense <<~RUBY
      def names
        results = []
        items.each { |x| results << x.name if x.valid? }
        results
      end
    RUBY
  end
end
