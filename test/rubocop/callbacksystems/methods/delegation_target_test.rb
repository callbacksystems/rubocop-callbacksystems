require "test_helper"

class RuboCop::Callbacksystems::Methods::DelegationTargetTest < ActiveSupport::TestCase
  include SourceParsing

  test "delegable? returns true for a constant" do
    assert target_in("Currency.factor").delegable?
  end

  test "delegable? returns true for a call on self" do
    assert target_in("registry.size").delegable?
  end

  test "delegable? returns true for a call on explicit self" do
    assert target_in("self.registry.size").delegable?
  end

  test "delegable? returns false for a receiver carrying arguments" do
    assert_not target_in("registry.fetch(key).size").delegable?
  end

  test "delegable? returns false without a receiver" do
    assert_not target_in("size").delegable?
  end

  test "delegable? handles a deep receiver chain without recursive descent" do
    source = "root#{".child" * 2_000}.size"

    assert target_in(source).delegable?
  end

  test "source returns the constant on its own" do
    assert_equal "Pay::Currency", target_in("Pay::Currency.factor").source
  end

  test "source returns a symbol for a single call on self" do
    assert_equal ":registry", target_in("registry.size").source
  end

  test "source returns a symbol for a single call on explicit self" do
    assert_equal ":registry", target_in("self.registry.size").source
  end

  test "source returns a dotted string for a chain" do
    assert_equal "\"config.postgres\"", target_in("config.postgres.names").source
  end

  test "name returns the constant source" do
    assert_equal "Currency", target_in("Currency.factor").name
  end

  test "name returns the chain joined by dots" do
    assert_equal "config.postgres", target_in("config.postgres.names").name
  end

  test "nested? returns true for a chain of calls" do
    assert target_in("config.postgres.names").nested?
  end

  test "nested? returns false for a constant" do
    assert_not target_in("Currency.factor").nested?
  end

  test "nested? returns false for a single call on self" do
    assert_not target_in("registry.size").nested?
  end

  private
    def target_in(source)
      receiver = processed_source(source).ast.receiver
      RuboCop::Callbacksystems::Methods::DelegationTarget.new(receiver)
    end
end
