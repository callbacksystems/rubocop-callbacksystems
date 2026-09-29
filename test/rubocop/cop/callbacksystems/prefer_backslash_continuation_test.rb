require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferBackslashContinuationTest < CopTestCase
  include SourceParsing

  self.cop_class = RuboCop::Cop::Callbacksystems::PreferBackslashContinuation

  NARROW_LINES = { "Layout/LineLength" => { "Max" => 20 } }
  ROOMY_LINES = { "Layout/LineLength" => { "Max" => 120 } }

  test "allows a call that is one side of a boolean expression" do
    assert_no_offense <<~RUBY
      def allowed?
        flag.present? && Proof.consume(
          token: token,
          scope: scope)
      end
    RUBY
  end

  test "allows a parenthesized call used as a range endpoint" do
    assert_no_offense <<~RUBY
      records = build_records(
        first,
        second
      )..last_record
    RUBY
  end

  test "allows a parenthesized call matched by rightward assignment" do
    assert_no_offense <<~RUBY
      build_record(
        first,
        second
      ) => record
    RUBY
  end

  test "allows a parenthesized call used as a constant namespace" do
    assert_no_offense <<~RUBY
      build_namespace(
        first,
        second
      )::Record
    RUBY
  end

  test "allows a call that carries a block after its closing parenthesis" do
    assert_no_offense <<~RUBY
      retry_on(
        SomeError,
        attempts: 10
      ) { |_, error| report(error) }
    RUBY
  end

  test "allows a call whose argument is a multiline conditional" do
    assert_no_offense <<~RUBY
      Array.wrap(
        if node.nil?
          nil
        else
          node.text
        end
      )
    RUBY
  end

  test "allows a call whose argument opens with a brace and chains from it" do
    assert_no_offense <<~RUBY
      Event.create!(
        {
          starts_at: 1,
          ends_at: 2
        }.merge(**attributes)
      )
    RUBY
  end

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

  test "autocorrects the last argument of a bare command to a backslash continuation" do
    assert_correction <<~RUBY, <<~CORRECTED
      get availability_path(
        line_item, rule_id: rule.id, sid: cart.signed_id
      )
    RUBY
      get availability_path \\
        line_item, rule_id: rule.id, sid: cart.signed_id
    CORRECTED
  end

  test "allows an opening comment when the last argument already carries another comment" do
    assert_no_offense <<~RUBY
      execute( # why
        body: <<~SQL # query
          select 1
        SQL
      )
    RUBY
  end

  test "allows a nested call followed by another argument of the bare command" do
    assert_no_offense <<~RUBY
      get availability_path(
        line_item, rule_id: rule.id
      ), params: { sid: cart.signed_id }
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

  test "allows a call whose argument runs past the opening line" do
    assert_no_offense <<~RUBY
      selections.add(rule: rule, params: {
        starts_at: starts_at,
        ends_at: ends_at
      })
    RUBY
  end

  test "allows a call whose first argument is a multiline array" do
    assert_no_offense <<~RUBY
      compare([
        first,
        second
      ], actual)
    RUBY
  end

  test "registers offense for a call leaving its first argument on the opening line" do
    assert_offense <<~RUBY
      preference = Preference.create(client,
        items: items)
    RUBY
  end

  test "corrects a first argument left on the opening line" do
    assert_correction <<~RUBY, <<~CORRECTED
      preference = Preference.create(client,
        items: items)
    RUBY
      preference = Preference.create \\
        client,
        items: items
    CORRECTED
  end

  test "corrects a first argument carrying a trailing comment on the opening line" do
    assert_correction <<~RUBY, <<~CORRECTED
      SomeReallyLongNamespace::Client.build(first_argument, # keep this argument note
        second_argument,
        third_argument)
    RUBY
      SomeReallyLongNamespace::Client.build \\
        first_argument, # keep this argument note
        second_argument,
        third_argument
    CORRECTED
  end

  test "corrects an indented call keeping the arguments that share the opening line together" do
    assert_correction <<~RUBY, <<~CORRECTED
      def build
        record.assign(alpha, beta,
          gamma: gamma)
      end
    RUBY
      def build
        record.assign \\
          alpha, beta,
          gamma: gamma
      end
    CORRECTED
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

  test "corrects a trailing shorthand keyword without letting it consume the following expression" do
    assert_correction <<~RUBY, <<~'CORRECTED'
      request = CorrectionRequest.new(
        range, message:, severity:, correction:, rewrites_comments:
      )
      if reserve(request.range)
        pending << request
      end
    RUBY
      request = CorrectionRequest.new \
        range, message:, severity:, correction:, rewrites_comments: rewrites_comments
      if reserve(request.range)
        pending << request
      end
    CORRECTED
  end

  test "expands a final shorthand before a following statement" do
    assert_correction <<~RUBY, <<~CORRECTED, config: NARROW_LINES
      Foo.new(
        nested_class, declaration:, project_index:
      )
      next_statement
    RUBY
      Foo.new \\
        nested_class, declaration:, project_index: project_index
      next_statement
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

  test "corrects leaving a comment above the closing parenthesis where it was" do
    assert_correction <<~RUBY, <<~CORRECTED
      some_method(
        arg1: value1,
        arg2: value2
        # keep this note
      )
    RUBY
      some_method \\
        arg1: value1,
        arg2: value2
        # keep this note
    CORRECTED
  end

  test "corrects leaving a trailing comment on the last argument where it was" do
    assert_correction <<~RUBY, <<~CORRECTED
      some_method(
        arg1: value1,
        arg2: value2 # keep this note
      )
    RUBY
      some_method \\
        arg1: value1,
        arg2: value2 # keep this note
    CORRECTED
  end

  test "corrects dropping a trailing comma that a comment follows" do
    assert_correction <<~RUBY, <<~CORRECTED
      some_method(
        arg1: value1,
        arg2: value2, # keep this note
      )
    RUBY
      some_method \\
        arg1: value1,
        arg2: value2 # keep this note
    CORRECTED
  end

  test "corrects moving a comment after the opening parenthesis to the last argument" do
    assert_correction <<~RUBY, <<~CORRECTED
      some_method( # why these
        arg1: value1,
        arg2: value2
      )
    RUBY
      some_method \\
        arg1: value1,
        arg2: value2 # why these
    CORRECTED
  end

  test "reports without moving a tooling comment after the opening parenthesis" do
    assert_uncorrectable_offense <<~RUBY
      some_method( # :nocov:
        arg1: value1,
        arg2: value2
      )
      # :nocov:
    RUBY
  end

  test "corrects moving a comment after the opening parenthesis to the opener of a last heredoc argument" do
    assert_correction <<~RUBY, <<~CORRECTED
      execute( # why
        body: <<~SQL
          select 1
        SQL
      )
    RUBY
      execute \\
        body: <<~SQL # why
          select 1
        SQL
    CORRECTED
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

  test "does not correct when a comment stands above the first argument" do
    code = <<~RUBY
      some_method(
        # about these
        arg1: value1,
        arg2: value2
      )
    RUBY

    RuboCop::Callbacksystems::Autocorrection::Batch.bypassing { assert_correction code, code }
  end

  test "corrects past the body of a trailing heredoc" do
    assert_correction <<~RUBY, <<~CORRECTED
      execute(
        name: "report",
        body: <<~SQL
          select 1
        SQL
      )
    RUBY
      execute \\
        name: "report",
        body: <<~SQL
          select 1
        SQL
    CORRECTED
  end

  test "corrects past a heredoc body sitting below the last argument" do
    assert_correction <<~RUBY, <<~CORRECTED
      execute(
        <<~SQL, quiet
          select 1
        SQL
      )
    RUBY
      execute \\
        <<~SQL, quiet
          select 1
        SQL
    CORRECTED
  end

  test "allows a call that is a branch of a ternary" do
    assert_no_offense <<~RUBY
      def allowed?
        marker.present? ? marker.include?("allow") : matches_all_of("policy", "pass")
      end
    RUBY
  end

  test "allows a call carrying a modifier if" do
    assert_no_offense <<~RUBY
      def notify
        deliver_message("welcome", recipient.email_address) if recipient.subscribed?
      end
    RUBY
  end

  test "allows a call handing over a named block" do
    assert_no_offense <<~RUBY
      link_to(notification,
        class: classes,
        &block)
    RUBY
  end

  test "allows a call handing over an anonymous block" do
    assert_no_offense <<~RUBY
      def wrapper(&)
        link_to(notification,
          class: classes,
          &)
      end
    RUBY
  end

  test "allows a parenthesized multiline call forwarding anonymous positional arguments" do
    assert_no_offense <<~RUBY
      def dispatch(*)
        perform(
          *
        )
      end
    RUBY
  end

  test "allows a parenthesized multiline call forwarding anonymous keyword arguments" do
    assert_no_offense <<~RUBY
      def dispatch(**)
        perform(
          **
        )
      end
    RUBY
  end

  test "allows an outer call whose argument contains a multiline safe-navigation call" do
    assert_no_offense <<~RUBY
      consume(
        object&.perform(
          argument
        )
      )
    RUBY
  end

  test "allows a call whose closing parenthesis is still on a line of its own" do
    assert_no_offense <<~RUBY
      Capybara::Selenium::Driver.new(app,
        browser: :remote,
        url: selenium_url,
        options: driver_options
      )
    RUBY
  end

  test "allows a call passed as an argument to super" do
    assert_no_offense <<~RUBY
      def rich_textarea_tag(name, value = nil, options = {})
        super(name, trix_html_for(value.try(:fragment) || value,
          auto_link: options.delete(:auto_link)), options)
      end
    RUBY
  end

  test "allows a call assigned inside a condition" do
    assert_no_offense <<~RUBY
      unless @blob = ActiveStorage::Blob.find_signed(params[:signed_blob_id] || params[:signed_id],
        purpose: "active_storage/blob/email")
        head :not_found
      end
    RUBY
  end

  test "allows a call matched by a when clause" do
    assert_no_offense <<~RUBY
      case
      when Invitation.taken?(email_address,
        account, scope: invitations) then "Already invited"
      else "Available"
      end
    RUBY
  end

  test "allows a call standing as a default in a parameter list" do
    assert_no_offense <<~RUBY
      def initialize(workspace:, lock_dir: ENV.fetch("A_KEY",
        DEFAULT_DIRECTORY), output: $stdout)
      end
    RUBY
  end

  test "allows a call short enough to sit on one line, which another cop collapses" do
    assert_no_offense <<~RUBY, config: ROOMY_LINES
      claim = Claim.new(
        invitation: invitation,
        name: "Test User"
      )
    RUBY
  end

  test "registers offense for a call too long to sit on one line" do
    assert_offense <<~RUBY, config: ROOMY_LINES
      claim = Account::Invitation::Claim.new(
        invitation: invitations(:bruno_the_reviewer_of_this_particular_account),
        name: "A name long enough to keep this call off a single line"
      )
    RUBY
  end

  test "an unknown structural kind matches no descendants" do
    root = processed_source("perform(work)").ast
    descendants = self.class.cop_class::StructuralContents::Descendants.new(root, :unknown)

    assert_not descendants.including?(root)
  end

  private
    def cop_investigation(source, file: DEFAULT_FILE, config: nil, project_sources: nil)
      super(source, file:, config: config || NARROW_LINES, project_sources:)
    end
end
