require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccessTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccess

  test "registers offense for [1]" do
    assert_offense <<~RUBY
      items[1]
    RUBY
  end

  test "registers offense for [2]" do
    assert_offense <<~RUBY
      items[2]
    RUBY
  end

  test "registers offense for [3]" do
    assert_offense <<~RUBY
      items[3]
    RUBY
  end

  test "registers offense for [4]" do
    assert_offense <<~RUBY
      items[4]
    RUBY
  end

  test "registers offense for [-2]" do
    assert_offense <<~RUBY
      items[-2]
    RUBY
  end

  test "registers offense for [-3]" do
    assert_offense <<~RUBY
      items[-3]
    RUBY
  end

  test "autocorrects [1] to second" do
    assert_correction "items[1]", "items.second"
  end

  test "autocorrects [2] to third" do
    assert_correction "items[2]", "items.third"
  end

  test "autocorrects [-2] to second_to_last" do
    assert_correction "items[-2]", "items.second_to_last"
  end

  test "autocorrects with method chain" do
    assert_correction "users.active[1]", "users.active.second"
  end

  test "autocorrects while preserving safe navigation" do
    assert_correction "users&.[](1)", "users&.second"
  end

  test "reports without correcting an indexed read containing a comment" do
    source = <<~RUBY
      items[
        # Skip the heading.
        1
      ]
    RUBY

    assert_uncorrectable_offense source
    assert_no_correction source
  end

  test "reports without correcting an indexed read containing a tooling comment" do
    source = <<~RUBY
      items[
        # :nocov:
        1
      ]
    RUBY

    assert_uncorrectable_offense source
    assert_no_correction source
  end

  test "does not register offense for [0]" do
    assert_no_offense <<~RUBY
      items[0]
    RUBY
  end

  test "does not register offense for [5]" do
    assert_no_offense <<~RUBY
      items[5]
    RUBY
  end

  test "does not register offense for [-1]" do
    assert_no_offense <<~RUBY
      items[-1]
    RUBY
  end

  test "does not register offense for [-4]" do
    assert_no_offense <<~RUBY
      items[-4]
    RUBY
  end

  test "does not register offense for string index" do
    assert_no_offense <<~RUBY
      hash["key"]
    RUBY
  end

  test "does not register offense for symbol index" do
    assert_no_offense <<~RUBY
      hash[:key]
    RUBY
  end

  test "does not register offense for variable index" do
    assert_no_offense <<~RUBY
      items[index]
    RUBY
  end

  test "does not register offense for range index" do
    assert_no_offense <<~RUBY
      items[1..3]
    RUBY
  end

  test "does not register offense for a string receiver" do
    assert_no_offense <<~RUBY
      "value"[2]
    RUBY
  end

  test "does not register offense for a call known to return a string" do
    assert_no_offense <<~RUBY
      name.upcase[1]
    RUBY
  end

  test "does not register offense for an integer-keyed hash receiver" do
    assert_no_offense <<~RUBY
      { 2 => "value" }[2]
    RUBY
  end

  test "does not register offense for a MatchData receiver" do
    assert_no_offense <<~RUBY
      value.match(/pattern/)[2]
      Regexp.last_match[2]
    RUBY
  end
  test "allows a receiver read out of another bracket access" do
    assert_no_offense <<~RUBY
      grouped[key][1]
    RUBY
  end

  test "allows a receiver read as a hash" do
    assert_no_offense <<~RUBY
      counts.tally[1]
    RUBY
  end

  test "allows a match data receiver" do
    assert_no_offense <<~RUBY
      text.match(/(a)(b)/)[1]
    RUBY
  end

  test "registers offense for a receiver split into an array" do
    assert_offense <<~RUBY
      text.split(",")[1]
    RUBY
  end
  test "allows a variable the same scope assigns a match data" do
    assert_no_offense <<~RUBY
      def parts_of(text)
        matches = text.match(/(a)(b)/)
        matches[1]
      end
    RUBY
  end

  test "allows a variable the same scope assigns a hash" do
    assert_no_offense <<~RUBY
      def value_of(pairs)
        counts = pairs.to_h
        counts[1]
      end
    RUBY
  end

  test "allows a variable assigned a match data inside a block" do
    assert_no_offense <<~RUBY
      lines.each do |line|
        matches = line.match(/(a)(b)/)
        puts matches[1]
      end
    RUBY
  end

  test "allows a variable rebound by pattern matching" do
    assert_no_offense <<~RUBY
      def second_part(input)
        parts = text.split(",")
        input => { parts: }
        parts[1]
      end
    RUBY
  end

  test "allows a variable assigned through multiple assignment whose type is unknown" do
    assert_no_offense <<~RUBY
      def second_part(input)
        parts, remainder = input
        parts[1]
      end
    RUBY
  end

  test "registers offense for a variable the same scope assigns an array" do
    assert_offense <<~RUBY
      def parts_of(text)
        parts = text.split(",")
        parts[1]
      end
    RUBY
  end

  test "registers offense for a variable when another one in the scope holds a match data" do
    assert_offense <<~RUBY
      def parts_of(text)
        matches = text.match(/(a)(b)/)
        parts = text.split(",")
        parts[1]
      end
    RUBY
  end

  test "allows an index read on a variable another assignment names" do
    assert_no_offense <<~RUBY
      class Report
        def first_row
          other = build_rows
          rows[0]
        end
      end
    RUBY
  end

  test "ignores a same-named non-array assignment inside a nested method" do
    assert_offense <<~RUBY
      def second_part(text)
        parts = text.split(",")

        Class.new do
          def unrelated
            parts = {}.to_h
          end
        end

        parts[1]
      end
    RUBY
  end
end
