require "test_helper"

class RuboCop::Callbacksystems::Autocorrection::BatchTest < ActiveSupport::TestCase
  include SourceParsing

  test "bypassing is reset when a correction raises" do
    assert_raises(RuntimeError) do
      RuboCop::Callbacksystems::Autocorrection::Batch.bypassing { raise "broken correction" }
    end

    assert_not_predicate RuboCop::Callbacksystems::Autocorrection::Batch, :bypassed?
  end

  test "bypassed? remains true through nested bypassing calls" do
    RuboCop::Callbacksystems::Autocorrection::Batch.bypassing do
      RuboCop::Callbacksystems::Autocorrection::Batch.bypassing { nil }

      assert_predicate RuboCop::Callbacksystems::Autocorrection::Batch, :bypassed?
    end

    assert_not_predicate RuboCop::Callbacksystems::Autocorrection::Batch, :bypassed?
  end

  test "bypassed? is false outside the current thread" do
    RuboCop::Callbacksystems::Autocorrection::Batch.bypassing do
      assert_not Thread.new { RuboCop::Callbacksystems::Autocorrection::Batch.bypassed? }.value
    end
  end

  test "correction_for accepts independent corrections after one rehearsal" do
    processed = processed_source((1..40).map { "value_#{it} = #{it}\n" }.join)
    entries = processed.ast.each_node(:int).map { Entry.new(replacing(it, with: it.value.next.to_s)) }
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new(entries, processed)

    parses = prism_parse_count do
      entries.each { assert batch.correction_for(it) }
    end

    assert_equal 1, parses
  end

  test "correction_for withholds the whole batch when one correction is invalid" do
    processed = processed_source("first = 1\nsecond = 2\n")
    first, second = processed.ast.each_node(:int).to_a
    invalid = Entry.new(replacing(first, with: "("))
    valid = Entry.new(replacing(second, with: "3"))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ invalid, valid ], processed)

    assert_nil batch.correction_for(invalid)
    assert_nil batch.correction_for(valid)
    assert_equal "first = 1\nsecond = 2\n", corrected(processed, [ invalid, valid ], batch)
  end

  test "correction_for accepts edits that make valid syntax together" do
    processed = processed_source("value = 1\n")
    range = processed.ast.source_range
    opening = Entry.new(->(corrector) { corrector.insert_before(range, "(") })
    closing = Entry.new(->(corrector) { corrector.insert_after(range, ")") })
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ opening, closing ], processed)

    assert_equal "(value = 1)\n", corrected(processed, [ opening, closing ], batch)
  end

  test "correction_for withholds corrections that clobber the same range" do
    processed = processed_source("value = 1\n")
    literal = processed.ast.each_node(:int).first
    first = Entry.new(replacing(literal, with: "2"))
    second = Entry.new(replacing(literal, with: "3"))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ first, second ], processed)

    assert_nil batch.correction_for(first)
    assert_nil batch.correction_for(second)
  end

  test "correction_for rescues a comment when a lone correction swallows it" do
    processed = processed_source("value = 1 # keep\n")
    entry = Entry.new(replacing(processed.ast, with: "value = 2"))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ entry ], processed)

    assert_equal "value = 2 # keep\n", corrected(processed, [ entry ], batch)
  end

  test "correction_for admits the whole batch after rescuing one entry" do
    processed = processed_source("first = 1 # keep\nsecond = 2\n")
    first, second = processed.ast.each_node(:int).to_a
    rescued = Entry.new(replacing(first.parent, with: "first = 3"))
    unchanged = Entry.new(replacing(second, with: "4"))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ rescued, unchanged ], processed)

    assert_equal "first = 3 # keep\nsecond = 4\n", corrected(processed, [ rescued, unchanged ], batch)
  end

  test "correction_for rescues a large batch with two aggregate rehearsals" do
    processed = processed_source((1..40).map { "value_#{it} = #{it} # keep #{it}\n" }.join)
    assignments = processed.ast.each_node(:lvasgn).to_a
    entries = assignments.map.with_index do |assignment, index|
      range = assignment.source_range.join(processed.comments.fetch(index).source_range)
      Entry.new(replacing(range, with: "#{assignment.name} = #{assignment.children.last.value.next}"))
    end
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new(entries, processed)

    parses = prism_parse_count do
      assert entries.all? { batch.correction_for(it) }
    end

    assert_equal 2, parses
    assert_equal 40, corrected(processed, entries, batch).scan(/# keep \d+/).size
  end

  test "correction_for rehearses deliberate comment rewrites as one batch" do
    processed = processed_source((1..40).map { "# ===== Section #{it} =====\nvalue_#{it} = #{it}\n" }.join)
    entries = processed.comments.map.with_index do |comment, index|
      Entry.new(replacing(comment, with: "# Section #{index.next}"), rewrites_comments: true)
    end
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new(entries, processed)

    parses = prism_parse_count do
      assert entries.all? { batch.correction_for(it) }
    end

    assert_equal 1, parses
    assert_equal 40, corrected(processed, entries, batch).scan(/# Section \d+/).size
  end

  test "correction_for does not cache a bypassed decision" do
    processed = processed_source("value = 1\n")
    entry = Entry.new(replacing(processed.ast.children.last, with: "("))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ entry ], processed)

    RuboCop::Callbacksystems::Autocorrection::Batch.bypassing { assert batch.correction_for(entry) }

    assert_nil batch.correction_for(entry)
  end

  test "correction_for bypasses a previously cached rejection" do
    processed = processed_source("value = 1\n")
    entry = Entry.new(replacing(processed.ast.children.last, with: "("))
    batch = RuboCop::Callbacksystems::Autocorrection::Batch.new([ entry ], processed)

    assert_nil batch.correction_for(entry)

    RuboCop::Callbacksystems::Autocorrection::Batch.bypassing { assert batch.correction_for(entry) }
  end

  private
    def replacing(node, with:)
      ->(corrector) { corrector.replace(node, with) }
    end

    def prism_parse_count
      singleton = Prism.singleton_class
      original = Prism.method(:parse)
      count = 0
      singleton.define_method(:parse) do |*arguments, **options|
        count += 1
        original.call(*arguments, **options)
      end
      yield.then { count }
    ensure
      singleton&.define_method(:parse, original) if original
    end

    def corrected(processed, entries, batch)
      RuboCop::Cop::Corrector.new(processed).tap do |corrector|
        entries.each { batch.correction_for(it)&.call(corrector) }
      end.rewrite
    end

    class Entry
      attr_reader :correction

      def initialize(correction, rewrites_comments: false)
        @correction = correction
        @rewrites_comments = rewrites_comments
      end

      def rewrites_comments?
        rewrites_comments
      end

      private
        attr_reader :rewrites_comments
    end
end
