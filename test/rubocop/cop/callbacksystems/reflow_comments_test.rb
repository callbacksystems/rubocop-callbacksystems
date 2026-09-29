require "test_helper"

class RuboCop::Cop::Callbacksystems::ReflowCommentsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ReflowComments

  test "allows a single comment line" do
    assert_no_offense <<~RUBY
      # One line only
      value = 1
    RUBY
  end

  test "allows breaks on sentence boundaries" do
    assert_no_offense <<~RUBY
      # First idea ends here.
      # Second idea starts here.
      value = 1
    RUBY
  end

  test "allows a numbered list" do
    assert_no_offense <<~RUBY
      # Order:
      #   1. first
      #   2. second
      value = 1
    RUBY
  end

  test "allows a dash list" do
    assert_no_offense <<~RUBY
      # Takes
      # - one
      # - two
      value = 1
    RUBY
  end

  test "leaves Markdown headings apart from the prose below them" do
    assert_no_offense <<~RUBY
      # ## Failure modes
      # A description that starts beneath the heading
      value = 1
    RUBY
  end

  test "leaves RDoc headings apart from the prose below them" do
    assert_no_offense <<~RUBY
      # == Failure modes
      # A description that starts beneath the heading
      value = 1
    RUBY
  end

  test "allows a block with an unbreakable word" do
    assert_no_offense <<~RUBY
      # See
      # https://example.com/#{"a" * 120}
      value = 1
    RUBY
  end

  test "allows trailing comments" do
    assert_no_offense <<~RUBY
      value = 1 # first
      other = 2 # second
    RUBY
  end

  test "allows a break when the next word does not fit" do
    assert_no_offense <<~RUBY
      # #{"a" * 110}
      # continuation here.
      value = 1
    RUBY
  end

  test "allows a line ending in a code tail" do
    assert_no_offense <<~RUBY
      # options = {
      # key: value }
      value = 1
    RUBY
  end

  test "allows a block with a backtick fence" do
    assert_no_offense <<~RUBY
      # ```ruby
      # value = 1
      # ```
      value = 1
    RUBY
  end

  test "allows a magic comment followed by a lone comment line" do
    assert_no_offense <<~RUBY
      # frozen_string_literal: true
      # a short open line
      value = 1
    RUBY
  end

  test "leaves a wrapped explanation beside a Steep directive untouched" do
    assert_no_offense <<~RUBY
      # steep:ignore:start
      # This directive should keep
      # applying to the next expression.
      dangerous_call
    RUBY
  end

  test "leaves a wrapped explanation beside a coverage sentinel untouched" do
    assert_no_offense <<~RUBY
      # This branch cannot run under
      # the supported Ruby version.
      # :nocov:
      impossible_branch
    RUBY
  end

  test "leaves a wrapped explanation inside Standard directives untouched" do
    assert_no_offense <<~RUBY
      # standard:disable Style/StringLiterals
      # This generated value must use
      # the upstream project's spelling.
      value = 'generated'
      # standard:enable Style/StringLiterals
    RUBY
  end

  test "allows a shebang followed by a lone comment line" do
    assert_no_offense <<~RUBY
      #!/usr/bin/env ruby
      # a short open line
      value = 1
    RUBY
  end

  test "leaves the gem's own cop headers with @example blocks alone" do
    path = "../../../../lib/rubocop/cop/callbacksystems/collapse_multiline_expression.rb"
    source = File.read(File.expand_path(path, __dir__))

    assert_includes source, "@example"
    assert_no_offense source
  end

  test "leaves adjacent YARD tags as separate records" do
    assert_no_offense <<~RUBY
      # @param name [String] the name that will be
      #   displayed to the reader
      # @return [String] the rendered name
      def render(name); end
    RUBY
  end

  test "leaves RDoc directives alone" do
    assert_no_offense <<~RUBY
      # :call-seq:
      #   render(name) -> string
      def render(name); end
    RUBY
  end

  test "registers offense with the project width in the message" do
    offenses = assert_offense <<~RUBY
      # A comment that stops
      # mid-sentence.
      value = 1
    RUBY

    assert_includes offenses.first.message, "120"
  end

  test "fills a comment that stops mid-sentence" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # A comment that stops
      # mid-sentence.
      value = 1
    RUBY
      # A comment that stops mid-sentence.
      value = 1
    CORRECTED
  end

  test "keeps the indentation of the block" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      class Widget
        # A method comment that stops
        # mid-sentence.
        def price
        end
      end
    RUBY
      class Widget
        # A method comment that stops mid-sentence.
        def price
        end
      end
    CORRECTED
  end

  test "fills each paragraph on its own and keeps the blank line between them" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # One idea that keeps
      # going.
      #
      # Another idea that also
      # wraps early.
      value = 1
    RUBY
      # One idea that keeps going.
      #
      # Another idea that also wraps early.
      value = 1
    CORRECTED
  end

  test "leaves alone a line opening with a label, which is an item of its own" do
    assert_no_offense <<~RUBY
      # Slot 1: 11:00-11:30, next start: 11:45
      # Slot 2: 11:45-12:15, next start: 12:30
      value = 1
    RUBY
  end

  test "leaves alone a short label whatever it is made of, from a week offset to a step count" do
    assert_no_offense <<~RUBY
      # Week+1: Bruno has 3 on Monday and 1 on Thursday
      # Step 1/2: Diego has 1 on Monday
      # Layer 3 (inferred): the office hours
      value = 1
    RUBY
  end

  test "leaves alone a line that reads as code" do
    assert_no_offense <<~RUBY
      # Retry jobs that encountered a deadlock
      # retry_on ActiveRecord::Deadlocked
      value = 1
    RUBY
  end

  test "leaves alone a commented-out call passing a string" do
    assert_no_offense <<~RUBY
      # Optional: Run system tests
      # step "Tests: System", "bin/rails test:system"
      value = 1
    RUBY
  end

  test "fills a wrapped sentence without pulling in the labeled line below it" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # The slots come out
      # in order.
      # Slot 1: 11:00-11:30
      value = 1
    RUBY
      # The slots come out in order.
      # Slot 1: 11:00-11:30
      value = 1
    CORRECTED
  end

  test "fills an open sentence and still keeps the labeled line below it apart" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # The slots come
      # out in order
      # Slot 1: 11:00-11:30
      value = 1
    RUBY
      # The slots come out in order
      # Slot 1: 11:00-11:30
      value = 1
    CORRECTED
  end

  test "closes a paragraph at a sentence boundary inside the block" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # First idea ends here.
      # Second idea that keeps
      # going on.
      value = 1
    RUBY
      # First idea ends here.
      # Second idea that keeps going on.
      value = 1
    CORRECTED
  end

  test "rewraps at the project width when the merged prose overflows" do
    assert_correction "# #{"x" * 80}\n# #{"y" * 30} #{"t" * 10}.\nvalue = 1\n",
      "# #{"x" * 80} #{"y" * 30}\n# #{"t" * 10}.\nvalue = 1\n"
  end
end
