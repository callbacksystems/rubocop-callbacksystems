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

  test "registers offense for multiline call inside a do/end block" do
    assert_offense <<~RUBY
      items.each do |item|
        log.info(
          name: item.name,
          id: item.id
        )
      end
    RUBY
  end

  test "registers offense for multiline call inside a brace block" do
    assert_offense <<~RUBY
      with_lock {
        update_columns(
          status: "done",
          updated_at: Time.current
        )
      }
    RUBY
  end

  test "registers offense for multiline call inside a test block" do
    assert_offense <<~RUBY
      test "does something" do
        assert_equal(
          expected,
          actual
        )
      end
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

  test "allows multiline call inside hash literal" do
    assert_no_offense <<~RUBY
      def attributes
        {
          payment_method_type: "card",
          default: default,
          data: card_data.merge(
            brand: object.payment_method&.dig("id") || object.payment_method&.dig("name")&.downcase,
            last4: object.last_four_digits,
            exp_month: object.expiration_month,
            exp_year: object.expiration_year
          )
        }
      end
    RUBY
  end

  test "allows multiline call inside array literal" do
    assert_no_offense <<~RUBY
      def items
        [
          build_item(
            name: "test",
            value: 42
          )
        ]
      end
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

  test "allows multiline call whose first argument is a braced hash" do
    assert_no_offense <<~RUBY
      assert_equal(
        {
          mon: { "09:00" => "18:00" },
          tue: { "09:00" => "18:00" }
        },
        config.hours
      )
    RUBY
  end

  test "allows call whose first argument shares the opening parenthesis line" do
    assert_no_offense <<~RUBY
      selections.add(rule: rule, params: {
        starts_at: starts_at,
        ends_at: ends_at
      })
    RUBY
  end

  test "corrects multiline constructor to backslash continuation" do
    assert_correction <<~RUBY, <<~CORRECTED
      claim = Account::Invitation::Claim.new(
        invitation: invitations(:bruno),
        name: "Test User"
      )
    RUBY
      claim = Account::Invitation::Claim.new \\
        invitation: invitations(:bruno),
        name: "Test User"
    CORRECTED
  end

  test "corrects positional arguments" do
    assert_correction <<~RUBY, <<~CORRECTED
      assert_equal(
        expected,
        actual
      )
    RUBY
      assert_equal \\
        expected,
        actual
    CORRECTED
  end

  test "corrects and drops a trailing comma" do
    assert_correction <<~RUBY, <<~CORRECTED
      some_method(
        arg1: value1,
        arg2: value2,
      )
    RUBY
      some_method \\
        arg1: value1,
        arg2: value2
    CORRECTED
  end

  test "does not correct when a comment precedes the closing parenthesis" do
    code = <<~RUBY
      some_method(
        arg1: value1,
        arg2: value2
        # keep this note
      )
    RUBY

    assert_correction code, code
  end

  test "does not correct a trailing comment on the last argument" do
    code = <<~RUBY
      some_method(
        arg1: value1,
        arg2: value2 # keep this note
      )
    RUBY

    assert_correction code, code
  end

  test "does not correct when a comment trails the closing parenthesis" do
    code = <<~RUBY
      some_method(
        arg1: value1,
        arg2: value2
      ) # keep this note
    RUBY

    assert_correction code, code
  end

  test "does not correct when the last argument is a heredoc" do
    code = <<~RUBY
      execute(
        name: "report",
        body: <<~SQL
          select 1
        SQL
      )
    RUBY

    assert_correction code, code
  end
end
