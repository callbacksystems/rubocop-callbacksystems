require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferBackslashContinuationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferBackslashContinuation

  test "registers offense for multiline method call with parentheses" do
    assert_offense <<~RUBY
      claim = Account::Invitation::Claim.new(
        invitation: invitations(:bruno),
        name: "Test User"
      )
    RUBY
  end

  test "registers offense for multiline non-constructor call with parentheses" do
    assert_offense <<~RUBY
      result = some_method(
        arg1: value1,
        arg2: value2
      )
    RUBY
  end

  test "allows single-line constructor call with parentheses" do
    assert_no_offense <<~RUBY
      user = User.new(name: "Bruno")
    RUBY
  end

  test "allows single-line method call with parentheses" do
    assert_no_offense <<~RUBY
      result = calculate(value)
    RUBY
  end

  test "allows multiline with backslash" do
    assert_no_offense <<~RUBY
      claim = Account::Invitation::Claim.new \\
        invitation: invitations(:bruno),
        name: "Test User"
    RUBY
  end

  test "allows method call without parentheses" do
    assert_no_offense <<~RUBY
      redirect_to account_path, notice: t(".success")
    RUBY
  end

  test "allows multiline without parentheses" do
    assert_no_offense <<~RUBY
      redirect_to account_path,
        notice: t(".success")
    RUBY
  end

  test "allows method call without arguments" do
    assert_no_offense <<~RUBY
      process
    RUBY
  end

  test "allows block calls even with multiline parentheses" do
    assert_no_offense <<~RUBY
      items.map { |i| i.name }
    RUBY
  end

  test "allows nested call inside another call" do
    assert_no_offense <<~RUBY
      update!(time_block: Model.find_or_create_by!(
        starts_at: starts_at,
        ends_at: ends_at
      ))
    RUBY
  end

  test "allows block disambiguation with parentheses" do
    assert_no_offense <<~RUBY
      concat(tag.div do
        content
      end)
    RUBY
  end

  test "allows call inside backslash continuation" do
    assert_no_offense <<~RUBY
      account.invitations.create \\
        inviter: self,
        invitee: account.people.new(
          name: name,
          email: email
        )
    RUBY
  end

  test "allows multiline call when result is chained with another method" do
    assert_no_offense <<~RUBY
      Pay::Mercadopago::Subscription.sync(
        preapproval.id,
        object: preapproval,
        pay_customer: self,
        name: name
      ).tap { it.update! }
    RUBY
  end

  test "allows multiline call with safe navigation chaining" do
    assert_no_offense <<~RUBY
      find_record(
        id: id,
        type: type
      )&.process
    RUBY
  end

  test "allows deeply nested calls" do
    assert_no_offense <<~RUBY
      outer(
        middle(
          inner(arg)
        )
      )
    RUBY
  end
end
