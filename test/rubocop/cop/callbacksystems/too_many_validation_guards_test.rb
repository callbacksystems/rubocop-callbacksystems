require "test_helper"

class RuboCop::Cop::Callbacksystems::TooManyValidationGuardsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::TooManyValidationGuards

  test "allows a method with no body" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "allows a single validation guard" do
    assert_no_offense <<~RUBY
      def process(account)
        return if account.nil?
        charge(account)
      end
    RUBY
  end

  test "allows two validation guards at the default maximum" do
    assert_no_offense <<~RUBY
      def process(account, plan)
        return if account.nil?
        return false unless plan
        charge(account)
      end
    RUBY
  end

  test "allows many dispatch branches that return values" do
    assert_no_offense <<~RUBY
      def label(value)
        return "one" if value == 1
        return "two" if value == 2
        return "three" if value == 3
        "other"
      end
    RUBY
  end

  test "does not treat multi-value returns beginning with a rejecting value as validation guards" do
    assert_no_offense <<~RUBY
      def result(account, plan, owner)
        return nil, "missing account" unless account
        return false, "missing plan" unless plan
        return nil, "missing owner" unless owner
        [true, account]
      end
    RUBY
  end

  test "registers offense for three leading validation guards" do
    offenses = assert_offense <<~RUBY
      def process(account, plan, owner)
        return unless account
        return false if plan.nil?
        return nil unless owner
        charge(account)
      end
    RUBY
    assert_includes offenses.first.message, "3 leading validation guards"
  end

  test "counts validation guards interleaved with assignments" do
    assert_offense <<~RUBY
      def process(account)
        return unless account
        owner = account.owner
        return if owner.nil?
        return false unless owner.active?
        charge(owner)
      end
    RUBY
  end

  test "stops counting at the first non-guard statement" do
    assert_no_offense <<~RUBY
      def process(account)
        return unless account
        return if account.closed?
        notify(account)
        return false unless account.active?
      end
    RUBY
  end
end
