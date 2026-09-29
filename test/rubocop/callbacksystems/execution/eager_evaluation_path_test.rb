require "test_helper"

class RuboCop::Callbacksystems::Execution::EagerEvaluationPathTest < ActiveSupport::TestCase
  include SourceParsing

  test "preserves_order? accepts the read itself as the boundary" do
    read, = read_and_statement_in("value")

    assert relocation_of(read, within: read).preserves_order?
  end

  test "preserves_order? accepts sequential nesting after literals and local reads" do
    read, statement = read_and_statement_in("consume(1, expected, [ value ])", before: "expected = true")

    assert relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects a read outside the boundary" do
    read, statement = read_and_statement_in("consume(value)")

    assert_not relocation_of(read, within: statement.parent.children.first).preserves_order?
  end

  test "preserves_order? rejects an earlier call" do
    read, statement = read_and_statement_in("consume(prepare, value)")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects an earlier mutable read" do
    read, statement = read_and_statement_in("consume(@state, value)")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? accepts an eagerly evaluated condition" do
    read, statement = read_and_statement_in("consume if value")

    assert relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects a conditional branch" do
    read, statement = read_and_statement_in("consume(value) if ready?")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? accepts the left side of a short circuit" do
    read, statement = read_and_statement_in("value || consume")

    assert relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects the right side of a short circuit" do
    read, statement = read_and_statement_in("ready? || consume(value)")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? accepts a safely navigated receiver" do
    read, statement = read_and_statement_in("value&.consume")

    assert relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects a safely navigated argument" do
    read, statement = read_and_statement_in("notifier&.consume(value)", parameters: "notifier")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? accepts a read in the immediate call of a block" do
    read, statement = read_and_statement_in("consume(value) { deferred }")

    assert relocation_of(read, within: statement).preserves_order?
  end

  test "preserves_order? rejects a read in a deferred block body" do
    read, statement = read_and_statement_in("consume { use(value) }")

    assert_not relocation_of(read, within: statement).preserves_order?
  end

  private
    def read_and_statement_in(expression, before: nil, parameters: nil)
      source = processed_source <<~RUBY
        def process(#{parameters})
          value = nil
          #{before}
          #{expression}
        end
      RUBY
      read = source.ast.each_descendant(:lvar).find { it.name == :value }

      [ read, source.ast.body.children.last ]
    end

    def relocation_of(read, within:)
      RuboCop::Callbacksystems::Execution::EagerEvaluationPath.new(read, within:)
    end
end
