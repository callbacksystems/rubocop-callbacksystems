require "test_helper"

class RuboCop::Cop::Callbacksystems::NoManualAccumulationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoManualAccumulation

  test "registers offense for array accumulation with each" do
    offenses = assert_offense <<~RUBY
      def names
        results = []
        items.each { |x| results << x.name }
        results
      end
    RUBY

    assert_includes offenses.first.message, "`map`, `select` or `filter_map`"
  end

  test "registers offense for hash accumulation with each" do
    offenses = assert_offense <<~RUBY
      def index
        hash = {}
        items.each { |x| hash[x.id] = x }
        hash
      end
    RUBY

    assert_includes offenses.first.message, "`index_by` or `to_h`"
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

  test "registers offense for safely navigated accumulation into an initialized array" do
    assert_offense <<~RUBY
      results = []
      items.each { |item| results&.push(item.name) }
    RUBY
  end

  test "registers offense for array accumulation with append" do
    assert_offense <<~RUBY
      results = []
      items.each { |x| results.append(x.name) }
    RUBY
  end

  test "registers offense for hash accumulation with store" do
    assert_offense <<~RUBY
      hash = {}
      items.each { |x| hash.store(x.id, x) }
    RUBY
  end

  test "registers offense for hash accumulation with merge!" do
    assert_offense <<~RUBY
      hash = {}
      items.each { |x| hash.merge!(x.id => x) }
    RUBY
  end

  test "registers offense for an accumulation that is not returned" do
    assert_offense <<~RUBY
      def process
        results = []
        items.each { |x| results << x.name }
        do_something(results)
      end
    RUBY
  end

  test "registers offense for each with << to local array" do
    assert_offense <<~RUBY
      results = []
      items.each { |item| results << item.name }
    RUBY
  end

  test "registers offense for each with << to instance variable array" do
    assert_offense <<~RUBY
      @results = []
      items.each { |item| @results << item }
    RUBY
  end

  test "registers offense for hash accumulation into an instance variable" do
    assert_offense <<~RUBY
      def initialize(items)
        @index = {}
        items.each { |item| @index[item.id] = item }
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

  test "registers offense for each with conditional <<" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        results << item if item.active?
      end
    RUBY
  end

  test "registers offense for each with << inside an if block" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        if item.active?
          results << item.name
        end
      end
    RUBY
  end

  test "registers offense for each with << guarded by unless" do
    assert_offense <<~RUBY
      results = []
      items.each { |item| results << item.name unless item.archived? }
    RUBY
  end

  test "registers offense for numblock with <<" do
    assert_offense <<~RUBY
      results = []
      items.each { results << _1.name }
    RUBY
  end

  test "registers offense for itblock with <<" do
    assert_offense <<~RUBY
      results = []
      items.each { results << it.name }
    RUBY
  end

  test "registers offenses when controls only occur in deferred callables for every block form" do
    assert_offense <<~RUBY, count: 3
      results = []
      items.each { |item| results << callback_for(item, -> { return }) }
      items.each { results << callback_for(_1, proc { raise }) }
      items.each { results << callback_for(it, Proc.new { next }) }
    RUBY
  end

  test "registers offense when control only occurs in a dynamically defined method" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        results << define_method(:callback) { return item }
      end
    RUBY
  end

  test "registers offense when control only occurs in a lexical method definition" do
    assert_offense <<~RUBY
      results = []
      items.each do
        results << (def callback
          return
        end)
      end
    RUBY
  end

  test "registers offense when another empty collection is assigned in between" do
    assert_offense <<~RUBY
      results = []
      other = {}
      items.each { |item| results << item.name }
    RUBY
  end

  test "registers offense when a statement separates the assignment from the each" do
    assert_offense <<~RUBY
      def names
        results = []
        log("collecting")
        items.each { |x| results << name_of(x) }
        results
      end
    RUBY
  end

  test "allows a collection name that was reassigned after its empty initialization" do
    assert_no_offense <<~RUBY
      results = []
      results = existing_results
      items.each { |item| results << item.name }
    RUBY
  end

  test "allows a collection conditionally reassigned after its empty initialization" do
    assert_no_offense <<~RUBY
      results = []
      results = existing_results if preserve_results?
      items.each { |item| results << item.name }
    RUBY
  end

  test "allows a collection reassigned while a singleton method receiver is evaluated" do
    assert_no_offense <<~RUBY
      results = []
      def (results = existing_results).run; end
      items.each { |item| results << item.name }
    RUBY
  end

  test "allows a collection reassigned by a capturing block" do
    assert_no_offense <<~RUBY
      results = []
      existing_results.tap { results = it }
      items.each { |item| results << item.name }
    RUBY
  end

  test "does not take an assignment to a shadowed block local as a reassignment" do
    assert_offense <<~RUBY
      results = []
      existing_results.tap { |results| results = replacement }
      items.each { |item| results << item.name }
    RUBY
  end

  test "does not take assignments in deferred scopes as reassignments" do
    assert_offense <<~RUBY
      results = []
      operation = proc { results = existing_results }

      def reset_results
        results = existing_results
      end

      items.each { |item| results << item.name }
    RUBY
  end

  test "allows an instance variable conditionally reassigned after its empty initialization" do
    assert_no_offense <<~RUBY
      @results = []
      @results = existing_results if preserve_results?
      items.each { |item| @results << item.name }
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

  test "allows map" do
    assert_no_offense <<~RUBY
      results = items.map(&:name)
    RUBY
  end

  test "allows select" do
    assert_no_offense <<~RUBY
      results = items.select(&:active?)
    RUBY
  end

  test "allows each_with_object" do
    assert_no_offense <<~RUBY
      items.each_with_object([]) { |item, arr| arr << item.name }
    RUBY
  end

  test "allows tap pattern" do
    assert_no_offense <<~RUBY
      [].tap do |results|
        items.each { |item| results << item }
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

  test "finds leaves through branches deeper than Ruby's call stack" do
    template = RuboCop::ProcessedSource.new("if ready?; work; end", RUBY_VERSION.to_f).ast
    leaf = RuboCop::AST::SendNode.new(:send, [ nil, :work ])
    body = 2_000.times.reduce(leaf) do |nested, _|
      RuboCop::AST::IfNode.new(:if, [ template.condition, nested, nil ], location: template.loc)
    end

    leaves = RuboCop::Cop::Callbacksystems::NoManualAccumulation::Accumulation::Leaves.new(body)

    assert_equal [ leaf ], leaves.each.to_a
  end

  test "allows each without <<" do
    assert_no_offense <<~RUBY
      items.each { |item| process(item) }
    RUBY
  end

  test "allows an each with no body" do
    assert_no_offense <<~RUBY
      results = []
      items.each { }
    RUBY
  end

  test "allows each with << to non-empty array" do
    assert_no_offense <<~RUBY
      results = [1, 2, 3]
      items.each { |item| results << item }
    RUBY
  end

  test "allows each filling a collection assigned elsewhere" do
    assert_no_offense <<~RUBY
      results = []
      items.each { |item| other << item }
    RUBY
  end

  test "registers offense for an array filled by index" do
    assert_offense <<~RUBY
      results = []
      items.each_with_index { |item, index| results[index] = item.name }
    RUBY
  end

  test "registers offense for an array filled with store" do
    assert_offense <<~RUBY
      results = []
      items.each_with_index { |item, index| results.store(index, item.name) }
    RUBY
  end

  test "registers offense for each with a mutation in both branches of an if" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        if item.active?
          results << item.name
        else
          results << item.id
        end
      end
    RUBY
  end

  test "registers offense for each with << inside a case" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        case item.kind
        when :person then results << item.name
        when :company then results << item.legal_name
        end
      end
    RUBY
  end

  test "registers offense for each with << inside an if nested in an unless" do
    assert_offense <<~RUBY
      results = []
      items.each do |item|
        unless item.archived?
          results << item.name if item.active?
        end
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

  test "allows a case with a side effect in a branch" do
    assert_no_offense <<~RUBY
      results = []
      items.each do |item|
        case item.kind
        when :person then results << item.name
        else log(item)
        end
      end
    RUBY
  end

  test "allows an each that skips items with next" do
    assert_no_offense <<~RUBY
      results = []
      items.each do |item|
        next unless item.valid?
        results << item.name
      end
    RUBY
  end

  test "allows an each whose mutation falls back to next" do
    assert_no_offense <<~RUBY
      results = []
      items.each { |item| results << (item.name || next) }
    RUBY
  end

  test "allows an each that stops with break" do
    assert_no_offense <<~RUBY
      results = []
      items.each { |item| results << (item.name || break) }
    RUBY
  end

  test "allows an each that returns from the method" do
    assert_no_offense <<~RUBY
      def names
        results = []
        items.each { |item| results << (item.name || return) }
        results
      end
    RUBY
  end

  test "allows an each that raises" do
    assert_no_offense <<~RUBY
      results = []
      items.each { |item| results << (item.name or raise ArgumentError) }
    RUBY
  end

  test "allows a control in a definition header evaluated by the each block" do
    assert_no_offense <<~RUBY
      results = []
      items.each do
        results << (def (raise ArgumentError).callback
        end)
      end
    RUBY
  end

  test "allows controls in ordinary nested blocks conservatively" do
    assert_no_offense <<~RUBY
      results = []
      items.each do |item|
        results << transaction { return item if item.invalid? }
      end
    RUBY
  end

  test "allows an accumulation a loop feeds, which the cop does not read into" do
    assert_no_offense <<~RUBY
      class Report
        def rows
          result = []

          if ready?
            while pending?
              result << next_item
            end
          end

          result
        end
      end
    RUBY
  end

  test "allows a method with an empty body" do
    assert_no_offense <<~RUBY
      class Report
        def rows
        end
      end
    RUBY
  end
end
