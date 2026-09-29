require "test_helper"

class RuboCop::Cop::Callbacksystems::NoLocalVariableReturnTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoLocalVariableReturn

  test "allows returning a parameter as it came" do
    assert_no_offense <<~RUBY
      def total(value)
        value
      end
    RUBY
  end

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

  test "registers offense without a fix for a pattern-bound local" do
    assert_uncorrectable_offense <<~RUBY
      def extract(payload)
        payload => { result: }
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

  test "inlines a local inside an explicit begin" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        begin
          result = calculate_something
          result
        end
      end
    RUBY
      def process
        begin
          calculate_something
        end
      end
    CORRECTED
  end

  test "keeps a comment about the returned value before the inlined expression" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        result = calculate_something
        # This is the value callers receive.
        result
      end
    RUBY
      def process
        # This is the value callers receive.
        calculate_something
      end
    CORRECTED
  end

  test "reports without a fix rather than dropping a trailing comment from the assignment" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = calculate_something # Explains how this value is built.
        result
      end
    RUBY
  end

  test "removes a blank line left between an assignment and its returned value" do
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

  test "inlines adjacent statements sharing a line" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        result = calculate_something; result
      end
    RUBY
      def process
        calculate_something
      end
    CORRECTED
  end

  test "inlines a safely navigated expression carrying an it block" do
    assert_correction <<~RUBY, <<~CORRECTED
      def names
        result = people&.map { it.name }
        result
      end
    RUBY
      def names
        people&.map { it.name }
      end
    CORRECTED
  end

  test "inlines despite names matching locals in nested lexical scopes" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        def nested
          result = other
          use(result)
        end

        Class.new do
          def nested
            result = other
            use(result)
          end
        end

        result = calculate_something
        result
      end
    RUBY
      def process
        def nested
          result = other
          use(result)
        end

        Class.new do
          def nested
            result = other
            use(result)
          end
        end

        calculate_something
      end
    CORRECTED
  end

  test "inlines despite a matching shadowed block local" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        items.each { |result| use(result) }
        result = calculate_something
        result
      end
    RUBY
      def process
        items.each { |result| use(result) }
        calculate_something
      end
    CORRECTED
  end

  test "reports a local captured by its assigned lambda without autocorrecting" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = -> { use(result) }
        result
      end
    RUBY
  end

  test "reports a local captured by a deferred singleton method receiver without autocorrecting" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = calculate_something(proc { def result.call; end })
        result
      end
    RUBY
  end

  test "reports a local pattern-bound by its assigned lambda without autocorrecting" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = -> { payload => { result: } }
        result
      end
    RUBY
  end

  test "reports without a fix when removing the assignment would change local-scope reflection" do
    [ "binding", "local_variables", 'eval("defined?(result)")', 'Kernel.eval("defined?(result)")' ].each do |value|
      assert_uncorrectable_offense <<~RUBY
        def process
          result = #{value}
          result
        end
      RUBY
    end
  end

  test "reports without a fix when moving the expression would change __LINE__" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = __LINE__
        # Keep the source line meaningful.
        result
      end
    RUBY
  end

  test "reports without a fix when inlining would change a tooling directive's scope" do
    assert_uncorrectable_offense <<~RUBY
      def process
        result = calculate_something
        # :nocov:
        result
      end
    RUBY
  end

  test "does not mistake a shadowed deferred callable argument for a capture" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        callback = ->(result) { use(result) }
        callback.call(other)
        result = calculate_something
        result
      end
    RUBY
      def process
        callback = ->(result) { use(result) }
        callback.call(other)
        calculate_something
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
  test "reports without a fix when the assigned value carries a heredoc" do
    assert_uncorrectable_offense <<~RUBY
      def report
        body = <<~TEXT
          hello
        TEXT
        body
      end
    RUBY
  end

  test "leaves a heredoc assignment untouched" do
    original = <<~RUBY
      def report
        body = <<~TEXT
          hello
        TEXT
        body
      end
    RUBY

    assert_correction original, original
  end

  test "allows a method closing with a bare return" do
    assert_no_offense <<~RUBY
      class Report
        def render
          draw
          return
        end
      end
    RUBY
  end

  test "registers offense without a fix when the assignment is not the statement above" do
    assert_offense <<~RUBY
      class Report
        def total
          amount = 1
          log(amount)
          amount
        end
      end
    RUBY
  end
end
