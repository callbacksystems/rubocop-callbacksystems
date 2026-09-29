require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::StatementRunTest < ActiveSupport::TestCase
  include SourceParsing

  test "rewrite replaces the span of the statements with them in the order given" do
    source = "def b; end\n\ndef c; end\n\ndef a; end\n"

    assert_equal "def a; end\n\ndef b; end\n\ndef c; end\n", rewritten(source, %i[ a b c ])
  end

  test "rewrite carries the comments of each statement along" do
    source = "# b\ndef b; end\n\n# a\ndef a; end\n"

    assert_equal "# a\ndef a; end\n\n# b\ndef b; end\n", rewritten(source, %i[ a b ])
  end

  test "rewrite leaves statements already in order alone" do
    source = "def a; end\n\ndef b; end\n"

    assert_equal source, rewritten(source, %i[ a b ])
  end

  test "rewrite leaves a run alone when a statement has no place in the order" do
    source = "def b; end\n\ndef a; end\n"

    assert_equal source, rewritten(source, %i[ a ])
  end

  test "rewrite keeps the first position when the order repeats a name" do
    source = "def b; end\n\ndef a; end\n"

    assert_equal "def a; end\n\ndef b; end\n", rewritten(source, %i[ a b a ])
  end

  test "rewrite indexes a large order once" do
    method_count = 2_000
    source = method_count.times.map { "def method_#{it}; end" }.join("\n\n") << "\n"
    order = method_count.times.reverse_each.map { :"method_#{it}" }

    assert_equal order, method_names_in(rewritten(source, order))
  end

  test "reorderable? is false for a run carrying a tooling directive" do
    source = <<~RUBY
      # rubocop:disable Metrics/MethodLength
      def b; end

      def a; end
      # rubocop:enable Metrics/MethodLength
    RUBY

    assert_equal source, rewritten(source, %i[ a b ])
  end

  private
    def rewritten(source, order)
      processed = processed_source(source)
      statements = processed.ast.children.map { RuboCop::Callbacksystems::Source::StatementWithComments.new(it, processed) }
      corrector = RuboCop::Cop::Corrector.new(processed)
      RuboCop::Callbacksystems::ClassStructure::StatementRun.new(statements, order:) { it.node.method_name }
        .rewrite(corrector)
      corrector.rewrite
    end

    def method_names_in(source)
      processed_source(source).ast.children.map(&:method_name)
    end
end
