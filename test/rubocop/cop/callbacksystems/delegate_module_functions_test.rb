require "test_helper"

class RuboCop::Cop::Callbacksystems::DelegateModuleFunctionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::DelegateModuleFunctions

  test "registers offense for a wrapper binding its own state" do
    offenses = assert_offense <<~RUBY
      class Charge
        def refund(amount)
          amount / subunit_factor(currency)
        end

        def subunit_factor
          Currency.subunit_factor(currency)
        end
      end
    RUBY

    assert_includes offenses.first.message, "delegate :subunit_factor, to: Currency"
    assert_includes offenses.first.message, "pass the arguments at the call sites"
  end

  test "registers offense for a private wrapper and suggests private: true" do
    offenses = assert_offense <<~RUBY
      class Charge
        private
          def subunit_factor
            Currency.subunit_factor(options[:currency])
          end
      end
    RUBY

    assert_includes offenses.first.message, "delegate :subunit_factor, to: Currency, private: true"
  end

  test "registers offense for a private wrapper forwarding its own parameters" do
    offenses = assert_offense <<~RUBY
      class Charge
        private
          def subunit_factor(currency)
            Currency.subunit_factor(currency)
          end
      end
    RUBY

    assert_includes offenses.first.message, "private: true"
    assert_not_includes offenses.first.message, "pass the arguments"
  end

  test "autocorrects a private wrapper forwarding its own parameters" do
    original = <<~RUBY
      class Charge
        private
          def subunit_factor(currency)
            Currency.subunit_factor(currency)
          end
      end
    RUBY

    corrected = <<~RUBY
      class Charge
        private
          delegate :subunit_factor, to: Currency, private: true
      end
    RUBY

    assert_correction original, corrected
  end

  test "autocorrects in place and leaves the placement to PrivateDelegatePlacement" do
    original = <<~RUBY
      class Charge
        private
          def refund_details
            { amount: amount }
          end

          def subunit_factor(currency)
            Currency.subunit_factor(currency)
          end
      end
    RUBY

    corrected = <<~RUBY
      class Charge
        private
          def refund_details
            { amount: amount }
          end

          delegate :subunit_factor, to: Currency, private: true
      end
    RUBY

    assert_correction original, corrected
  end

  test "does not autocorrect a wrapper binding its own state" do
    original = <<~RUBY
      class Charge
        private
          def subunit_factor
            Currency.subunit_factor(options[:currency])
          end
      end
    RUBY

    assert_correction original, original
  end

  test "registers offense with the full namespace of the target" do
    offenses = assert_offense <<~RUBY
      class Charge
        def subunit_factor
          Pay::Mercadopago::Currency.subunit_factor(currency)
        end
      end
    RUBY

    assert_includes offenses.first.message, "to: Pay::Mercadopago::Currency"
  end

  test "registers offense for an endless wrapper" do
    assert_offense <<~RUBY
      class Charge
        def subunit_factor = Currency.subunit_factor(currency)
      end
    RUBY
  end

  test "no offense for a public method forwarding its own parameters" do
    assert_no_offense <<~RUBY
      class Charge
        def subunit_factor(currency)
          Currency.subunit_factor(currency)
        end
      end
    RUBY
  end

  test "no offense for a wrapper with a different name" do
    assert_no_offense <<~RUBY
      class Charge
        def factor
          Currency.subunit_factor(currency)
        end
      end
    RUBY
  end

  test "no offense for a wrapper over a non-constant receiver" do
    assert_no_offense <<~RUBY
      class Charge
        def subunit_factor
          currency_converter.subunit_factor(currency)
        end
      end
    RUBY
  end

  test "no offense for a method with more than one statement" do
    assert_no_offense <<~RUBY
      class Charge
        def subunit_factor
          log_lookup
          Currency.subunit_factor(currency)
        end
      end
    RUBY
  end

  test "no offense for a protected wrapper" do
    assert_no_offense <<~RUBY
      class Charge
        protected
          def subunit_factor
            Currency.subunit_factor(currency)
          end
      end
    RUBY
  end
end
