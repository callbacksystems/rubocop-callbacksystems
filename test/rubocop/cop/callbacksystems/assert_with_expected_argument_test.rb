require "test_helper"

class RuboCop::Cop::Callbacksystems::AssertWithExpectedArgumentTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::AssertWithExpectedArgument

  test "registers offense when the second argument reads as a value" do
    assert_offense "assert(3, my_list.length)"
    assert_offense "assert(expected, actual)"
  end

  test "allows a string message" do
    assert_no_offense 'assert foo, "must be present"'
    assert_no_offense <<~'RUBY'
      assert foo, "expected #{foo} to be present"
    RUBY
  end

  test "allows lazily evaluated messages" do
    assert_no_offense <<~'RUBY'
      assert user, -> { "User #{user.id} must be persisted" }
      assert account, proc { "Account #{account.id} must be active" }
      assert order, Proc.new { "Order #{order.id} must be paid" }
    RUBY
  end

  test "allows variables named like messages" do
    assert_no_offense "assert foo, msg"
    assert_no_offense "assert foo, message"
    assert_no_offense "assert foo, error_message"
  end

  test "allows method calls named like messages" do
    assert_no_offense "assert audit.passed?, audit.failure_message"
    assert_no_offense "assert response.ok?, diagnostic_message"
  end

  test "allows any second argument after a predicate" do
    assert_no_offense "assert user.valid?, user.errors"
    assert_no_offense "assert list.empty?, list"
    assert_no_offense "assert user&.valid?, user.errors"
  end

  test "allows any second argument after an expression that is visibly boolean" do
    assert_no_offense "assert expected == actual, comparison_details"
    assert_no_offense "assert !errors.any?, errors"
    assert_no_offense "assert loaded && valid, state"
    assert_no_offense "assert payload in { status: :ready }, payload"
  end

  test "registers an explicitly self-qualified ambiguous assertion" do
    assert_offense "self.assert(expected, actual)"
  end

  test "registers an ambiguous assertion safely navigated on self" do
    assert_offense "self&.assert(expected, actual)"
  end

  test "allows a single-argument assert" do
    assert_no_offense "assert user.valid?"
  end

  test "reads an assertion whose second argument is not a call" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "it works" do
          assert user, @failure_message
        end
      end
    RUBY
  end

  test "allows an application API named assert" do
    assert_no_offense <<~RUBY, file: "lib/contracts.rb"
      assert(expected, actual)
    RUBY
  end
end
