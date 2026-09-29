require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDefaultArgumentTest < CopTestCase
  include SourceParsing

  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDefaultArgument

  test "registers offense for a positional parameter given a fallback with ||=" do
    assert_offense <<~RUBY
      def deliver(recipients)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "registers offense for a keyword parameter given a fallback with ||=" do
    assert_offense <<~RUBY
      def deliver(recipients: nil)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "registers offense for a fallback guarded with nil?" do
    assert_offense <<~RUBY
      def deliver(recipients)
        recipients = [ owner ] if recipients.nil?
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "registers offense for a fallback guarded with unless" do
    assert_offense <<~RUBY
      def deliver(recipients)
        recipients = [ owner ] unless recipients
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "registers offense for each of two parameters given fallbacks back to back" do
    assert_offense <<~RUBY, count: 2
      def deliver(recipients, subject: nil)
        recipients ||= [ owner ]
        subject ||= "Hello"
        recipients.each { mail(it, subject) }
      end
    RUBY
  end

  test "registers offense for a fallback in a class method" do
    assert_offense <<~RUBY
      def self.deliver(recipients)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "registers offense for a fallback reading a parameter to its left" do
    assert_offense <<~RUBY
      def deliver(sender, recipients)
        recipients ||= [ sender ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback that is not the first statement" do
    assert_no_offense <<~RUBY
      def deliver(recipients)
        prepare
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback for a required keyword" do
    assert_no_offense <<~RUBY
      def deliver(recipients:)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback for a keyword with a default of its own" do
    assert_no_offense <<~RUBY
      def deliver(recipients: [])
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback reading a parameter to its right" do
    assert_no_offense <<~RUBY
      def deliver(recipients, sender)
        recipients ||= [ sender ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback reading the parameter itself" do
    assert_no_offense <<~RUBY
      def deliver(recipients)
        recipients = Array(recipients) unless recipients
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback for a splat parameter" do
    assert_no_offense <<~RUBY
      def deliver(*recipients)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback for a positional parameter after a splat" do
    assert_no_offense <<~RUBY
      def deliver(*recipients, subject)
        subject ||= "Hello"
        recipients.each { mail(it, subject) }
      end
    RUBY
  end

  test "allows a fallback for a positional parameter after an anonymous splat" do
    assert_no_offense <<~RUBY
      def deliver(*, subject)
        subject ||= "Hello"
        mail(subject)
      end
    RUBY
  end

  test "allows a fallback reading a destructured parameter to its right" do
    assert_no_offense <<~RUBY
      def deliver(subject, (recipient, sender))
        subject ||= greeting_for(recipient, sender)
        mail(recipient, subject)
      end
    RUBY
  end

  test "allows a fallback reading keyword rest and block parameters to its right" do
    assert_no_offense <<~RUBY
      def deliver(subject, **options, &delivery)
        subject ||= options.fetch(:subject, delivery.call)
        mail(subject)
      end
    RUBY
  end

  test "allows a fallback for a local that is not a parameter" do
    assert_no_offense <<~RUBY
      def deliver
        recipients = nil
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback with an else branch" do
    assert_no_offense <<~RUBY
      def deliver(recipients)
        recipients = recipients.nil? ? [ owner ] : recipients.compact
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback that is the whole body" do
    assert_no_offense <<~RUBY
      def recipients(given)
        given ||= [ owner ]
      end
    RUBY
  end

  test "allows a fallback sharing a line with the signature" do
    assert_no_offense <<~RUBY
      def deliver(recipients) recipients ||= [ owner ]; recipients.each { mail(it) } end
    RUBY
  end

  test "allows a fallback spanning several lines" do
    assert_no_offense <<~RUBY
      def deliver(recipients)
        recipients ||= [
          owner
        ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "allows a fallback with a heredoc" do
    assert_no_offense <<~RUBY
      def deliver(subject)
        subject ||= <<~TEXT
          Hello
        TEXT
        mail(subject)
      end
    RUBY
  end

  test "allows a positional fallback that would open a second optional group" do
    assert_no_offense <<~RUBY
      def deliver(sender = owner, recipients, subject)
        subject ||= "Hello"
        recipients.each { mail(it, subject) }
      end
    RUBY
  end

  test "reports a positional fallback without a fix because nil, false, and omitted arguments differ" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end

      deliver(nil)
      deliver(false)
      method(:deliver).arity
    RUBY
  end

  test "reports a keyword fallback without a fix because explicit nil and false differ" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients: nil)
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end

      deliver(recipients: nil)
      deliver(recipients: false)
    RUBY
  end

  test "reports a fallback guarded with nil? without a fix because explicit nil differs" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients = [ owner ] if recipients.nil?
        recipients.each { mail(it) }
      end

      deliver(nil)
    RUBY
  end

  test "reports a fallback guarded with unless without a fix because explicit nil and false differ" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients = [ owner ] unless recipients
        recipients.each { mail(it) }
      end

      deliver(nil)
      deliver(false)
    RUBY
  end

  test "reports two fallbacks back to back without fixes" do
    offenses = assert_offense <<~RUBY, count: 2
      def deliver(recipients, subject: nil)
        recipients ||= [ owner ]
        subject ||= "Hello"

        recipients.each { mail(it, subject) }
      end
    RUBY

    assert offenses.all? { it.status == :unsupported }
  end

  test "reports without a fix a fallback reading a parameter to its left" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(sender, recipients)
        recipients ||= [ sender ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "reports without a fix a fallback reading a destructured parameter to its left" do
    assert_uncorrectable_offense <<~RUBY
      def deliver((recipient, sender), subject)
        subject ||= greeting_for(recipient, sender)
        mail(recipient, subject)
      end
    RUBY
  end

  test "reports without a fix a fallback before an anonymous destructured rest parameter" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(sender, subject, (*))
        subject ||= sender
        mail(subject)
      end
    RUBY
  end

  test "reports without a fix a fallback whose block parameter shadows a later method local" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients ||= people.map { |person| person.address }
        person = owner
        recipients.each { mail(it, from: person) }
      end
    RUBY
  end

  test "reports without a fix a fallback whose block parameter shadows a parameter to its right" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients, sender)
        recipients ||= people.map { |sender| sender.address }
        recipients.each { mail(it, from: sender) }
      end
    RUBY
  end

  test "reports without a fix a fallback carrying an it block" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients ||= people.map { it.address }
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "reports without a fix a fallback for a positional parameter before a splat" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(subject, *recipients, delivery)
        subject ||= "Hello"
        recipients.each { mail(it, subject, delivery) }
      end
    RUBY
  end

  test "reports without a fix a fallback before forwarded arguments" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(subject, ...)
        subject ||= "Hello"
        mail(subject, ...)
      end
    RUBY
  end

  test "reports without a fix only the keyword fallback when the positional one would open another optional group" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(sender = owner, recipients, subject, greeting: nil)
        greeting ||= "Hi"
        subject ||= "Hello"
        recipients.each { mail(it, subject, greeting) }
      end
    RUBY
  end

  test "reports a fallback with a trailing comment without a fix" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        recipients ||= [ owner ] # everyone otherwise
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "reports a fallback following a tooling directive without a fix" do
    assert_uncorrectable_offense <<~RUBY
      def deliver(recipients)
        # :nocov:
        recipients ||= [ owner ]
        recipients.each { mail(it) }
      end
    RUBY
  end

  test "parameter name enumeration returns every destructured name" do
    method = processed_source("def deliver((recipient, *others)); end").ast
    names = self.class.cop_class::ParameterNames.new(method.first_argument).each

    assert_instance_of Enumerator, names
    assert_equal %i[ recipient others ], names.to_a
  end
end
