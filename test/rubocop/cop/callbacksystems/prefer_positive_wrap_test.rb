require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferPositiveWrapTest < CopTestCase
  include SourceParsing

  self.cop_class = RuboCop::Cop::Callbacksystems::PreferPositiveWrap

  test "wraps a body whose last statement carries a squiggly heredoc" do
    assert_correction <<~BAD, <<~GOOD
      def up
        return unless ready?

        execute <<~SQL
          CREATE TABLE things (id integer)
        SQL
      end
    BAD
      def up
        if ready?
          execute <<~SQL
            CREATE TABLE things (id integer)
          SQL
        end
      end
    GOOD
  end

  test "reports without changing the contents of an indented heredoc" do
    assert_uncorrectable_offense <<~RUBY
      def up
        return unless ready?

        execute <<-SQL
          CREATE TABLE things (id integer)
        SQL
      end
    RUBY
  end

  test "allows a method whose first statement is not a guard at all" do
    assert_no_offense <<~RUBY
      def process
        deliver
        finish
      end
    RUBY
  end

  test "allows an unless guard whose branch does not return" do
    assert_no_offense <<~RUBY
      def process
        unless ready?
          deliver
        end
        finish
      end
    RUBY
  end

  test "registers offense for a bare-return guard with a short happy path" do
    assert_offense <<~RUBY
      def label
        return unless ready?
        compute_label
      end
    RUBY
  end

  test "registers offense for a value-return guard with a short happy path" do
    assert_offense <<~RUBY
      def descriptor
        return nil unless ready?
        { kind: :default }
      end
    RUBY
  end

  test "allows a deeply nested happy path: wrap would breach Metrics/BlockNesting" do
    assert_no_offense <<~RUBY
      def process
        return unless ready?
        if a
          if b
            if c
              do_stuff
            end
          end
        end
      end
    RUBY
  end

  test "uses a higher configured Metrics BlockNesting limit" do
    assert_offense <<~RUBY, config: { "Metrics/BlockNesting" => { "Max" => 4 } }
      def process
        return unless ready?
        if a
          if b
            if c
              do_stuff
            end
          end
        end
      end
    RUBY
  end

  test "uses a lower configured Metrics BlockNesting limit" do
    assert_no_offense <<~RUBY, config: { "Metrics/BlockNesting" => { "Max" => 1 } }
      def process
        return unless ready?
        if nested?
          do_stuff
        end
      end
    RUBY
  end

  test "allows a positive guard: `return if cond` is not a negative form" do
    assert_no_offense <<~RUBY
      def label
        return if hidden?
        compute_label
      end
    RUBY
  end

  test "allows a single-statement body" do
    assert_no_offense <<~RUBY
      def label
        compute_label
      end
    RUBY
  end

  test "rewrites the bare guard to a positive if-block" do
    assert_correction <<~RUBY, <<~CORRECTED
      def label
        return unless ready?
        compute_label
      end
    RUBY
      def label
        if ready?
          compute_label
        end
      end
    CORRECTED
  end

  test "rewrites a happy path sharing the guard's line" do
    assert_correction \
      "def process\n  return unless ready?; complete\nend\n",
      "def process\n  if ready?\n    complete\n  end\nend\n"
  end

  test "rewrites the value guard keeping the value in an else branch" do
    assert_correction <<~RUBY, <<~CORRECTED
      def descriptor
        return nil unless ready?
        { kind: :default }
      end
    RUBY
      def descriptor
        if ready?
          { kind: :default }
        else
          nil
        end
      end
    CORRECTED
  end

  test "rewrites a guard returning several values without losing any" do
    assert_correction <<~RUBY, <<~CORRECTED
      def coordinates
        return latitude, longitude unless located?
        precise_coordinates
      end
    RUBY
      def coordinates
        if located?
          precise_coordinates
        else
          [ latitude, longitude ]
        end
      end
    CORRECTED
  end

  test "reports without rewriting an unless guard that already has an else branch" do
    assert_uncorrectable_offense <<~RUBY
      def process
        unless ready?
          return fallback(:unready)
        else
          observe(:ready)
        end

        finish
      end
    RUBY
  end

  test "reports without rewriting a guard returning one positional splat" do
    assert_uncorrectable_offense <<~RUBY
      def coordinates
        return *fallback unless located?
        precise_coordinates
      end
    RUBY
  end

  test "reports without rewriting a guard returning one keyword splat" do
    assert_uncorrectable_offense <<~RUBY
      def attributes
        return **fallback unless loaded?
        loaded_attributes
      end
    RUBY
  end

  test "rewrites several returned values when one is a splat" do
    assert_correction <<~RUBY, <<~CORRECTED
      def coordinates
        return latitude, *fallback unless located?
        precise_coordinates
      end
    RUBY
      def coordinates
        if located?
          precise_coordinates
        else
          [ latitude, *fallback ]
        end
      end
    CORRECTED
  end

  test "rewrites a multi-statement happy path" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        return unless ready?
        first_step
        second_step
        third_step
      end
    RUBY
      def process
        if ready?
          first_step
          second_step
          third_step
        end
      end
    CORRECTED
  end

  test "rewrites a happy path keeping the blank line inside it" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        return unless ready?
        first_step

        second_step
      end
    RUBY
      def process
        if ready?
          first_step

          second_step
        end
      end
    CORRECTED
  end

  test "keeps a prose comment with the first happy-path statement" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        return unless ready?
        # This work completes the process.
        complete
      end
    RUBY
      def process
        if ready?
          # This work completes the process.
          complete
        end
      end
    CORRECTED
  end

  test "keeps coverage markers in their positions inside the happy path" do
    original = <<~RUBY
      def process
        return unless ready?
        # :nocov:
        uncovered_work
        # :nocov:
        covered_work
      end
    RUBY
    corrected = <<~RUBY
      def process
        if ready?
          # :nocov:
          uncovered_work
          # :nocov:
          covered_work
        end
      end
    RUBY

    assert_correction original, corrected
    assert_no_correction corrected
  end

  test "keeps the comment trailing the guard on the positive condition" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        return unless ready? # Work only makes sense when ready.
        complete
      end
    RUBY
      def process
        if ready? # Work only makes sense when ready.
          complete
        end
      end
    CORRECTED
  end

  test "keeps the comment trailing the final happy-path statement" do
    original = <<~RUBY
      def process
        return unless ready?
        complete # This is the returned value.
      end
    RUBY
    corrected = <<~RUBY
      def process
        if ready?
          complete # This is the returned value.
        end
      end
    RUBY

    assert_correction original, corrected
    assert_no_correction corrected
  end

  test "reports without moving a detached comment into the happy path" do
    assert_uncorrectable_offense <<~RUBY
      def process
        return unless ready?
        # This comment is deliberately separated.

        complete
      end
    RUBY
  end

  test "allows a method with an empty body" do
    assert_no_offense <<~RUBY
      class Report
        def render
        end
      end
    RUBY
  end

  test "allows a guard whose branch holds nothing to return" do
    assert_no_offense <<~RUBY
      class Report
        def render
          unless ready?
          end

          draw
        end
      end
    RUBY
  end

  test "registers offense when the happy path defines a method, which carries no depth of its own" do
    assert_offense <<~RUBY
      class Report
        def render
          return unless ready?

          def draw
            one { two { three { four } } }
          end
        end
      end
    RUBY
  end

  test "measures block nesting deeper than Ruby's call stack without recursion" do
    nested = 2_000.times.reduce(RuboCop::AST::Node.new(:nil)) do |body, _|
      RuboCop::AST::Node.new(:block, [ RuboCop::AST::Node.new(:send, [ nil, :run ]),
        RuboCop::AST::Node.new(:args), body ])
    end
    nesting = RuboCop::Cop::Callbacksystems::PreferPositiveWrap::BlockNesting.new("Max" => 2_001, "CountBlocks" => true)

    assert nesting.allows_wrap?([ nested ])
  end

  test "block-nesting descendants can be enumerated without a block" do
    root = processed_source("if ready? then perform end").ast
    descendants = self.class.cop_class::BlockNesting::Descendants.new(root).each

    assert_instance_of Enumerator, descendants
    assert_equal %i[ if send send ], descendants.map(&:type)
  end
end
