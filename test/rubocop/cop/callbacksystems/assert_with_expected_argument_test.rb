require "test_helper"

class RuboCop::Cop::Callbacksystems::AssertWithExpectedArgumentTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::AssertWithExpectedArgument

  test "registers offense when the second argument reads as a value" do
    assert_offense "assert(3, my_list.length)"
    assert_offense "assert(expected, actual)"
  end

  test "allows a string message" do
    assert_no_offense 'assert foo, "must be present"'
    assert_no_offense 'assert foo, "expected #{foo} to be present"'
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
  end

  test "allows a single-argument assert" do
    assert_no_offense "assert user.valid?"
  end
end
