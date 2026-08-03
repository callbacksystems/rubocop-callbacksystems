require "test_helper"

class HeredocBodiesTest < ActiveSupport::TestCase
  test "relocate writes the body under the line the expression collapsed onto" do
    processed = processed_source(<<~RUBY)
      PROBES = [
        <<~SQL
          select 1
        SQL
      ].freeze
    RUBY
    array = processed.ast.expression.receiver

    corrected = correcting(processed) do |corrector|
      corrector.replace(array, "[ <<~SQL ]")
      RuboCop::Callbacksystems::HeredocBodies.new(array).relocate(corrector)
    end

    assert_equal <<~CORRECTED, corrected
      PROBES = [ <<~SQL ].freeze
          select 1
        SQL
    CORRECTED
  end

  test "relocate keeps several bodies in the order their markers read" do
    processed = processed_source(<<~RUBY)
      compare(
        <<~LEFT,
          a
        LEFT
        <<~RIGHT
          b
        RIGHT
      )
    RUBY
    call = processed.ast

    corrected = correcting(processed) do |corrector|
      corrector.replace(call, "compare(<<~LEFT, <<~RIGHT)")
      RuboCop::Callbacksystems::HeredocBodies.new(call).relocate(corrector)
    end

    assert_equal <<~CORRECTED, corrected
      compare(<<~LEFT, <<~RIGHT)
          a
        LEFT
          b
        RIGHT
    CORRECTED
  end

  test "relocate leaves an expression holding no heredoc untouched" do
    processed = processed_source("wrap(body)\n")

    corrected = correcting(processed) do |corrector|
      RuboCop::Callbacksystems::HeredocBodies.new(processed.ast).relocate(corrector)
    end

    assert_equal "wrap(body)\n", corrected
  end

  test "relocate_under lands the body beneath a line elsewhere in the file" do
    processed = processed_source(<<~RUBY)
      body = <<~TEXT
        hello
      TEXT
      wrap(placeholder)
    RUBY
    value = processed.ast.children.first.expression
    destination = processed.ast.children.last.first_argument

    corrected = correcting(processed) do |corrector|
      corrector.replace(destination, "<<~TEXT")
      RuboCop::Callbacksystems::HeredocBodies.new(value).relocate_under(corrector, destination)
    end

    assert_equal <<~CORRECTED, corrected
      body = <<~TEXT
        hello
      TEXT
      wrap(<<~TEXT)
        hello
      TEXT
    CORRECTED
  end

  test "remove takes the body lines out of where they were" do
    processed = processed_source(<<~RUBY)
      body = <<~TEXT
        hello
      TEXT
      wrap(body)
    RUBY
    value = processed.ast.children.first.expression

    corrected = correcting(processed) do |corrector|
      corrector.remove(Helpers.line_removal_range_for(processed.ast.children.first))
      RuboCop::Callbacksystems::HeredocBodies.new(value).remove(corrector, covered_by: nil)
    end

    assert_equal "wrap(body)\n", corrected
  end

  test "remove leaves alone the lines the caller's own range already covers" do
    processed = processed_source(<<~RUBY)
      body = <<~TEXT
        hello
      TEXT
      wrap(body)
    RUBY
    assignment = processed.ast.children.first
    whole = assignment.source_range.with(end_pos: processed.buffer.source.index("wrap"))

    corrected = correcting(processed) do |corrector|
      corrector.remove(whole)
      RuboCop::Callbacksystems::HeredocBodies.new(assignment.expression).remove(corrector, covered_by: whole)
    end

    assert_equal "wrap(body)\n", corrected
  end

  private
    Helpers = RuboCop::Callbacksystems::Helpers

    def processed_source(source)
      RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "app/models/report.rb")
    end

    def correcting(processed)
      RuboCop::Cop::Corrector.new(processed).then do |corrector|
        yield corrector
        corrector.rewrite
      end
    end
end
