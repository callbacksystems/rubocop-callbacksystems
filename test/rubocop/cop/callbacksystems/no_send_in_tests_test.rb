require "test_helper"

class RuboCop::Cop::Callbacksystems::NoSendInTestsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoSendInTests

  test "registers offense for send in test block" do
    assert_offense <<~RUBY
      test "processes payment" do
        result = order.send(:process_payment)
        assert result
      end
    RUBY
  end

  test "registers offense for __send__ in test block" do
    assert_offense <<~RUBY
      test "processes payment" do
        order.__send__(:process_payment)
      end
    RUBY
  end

  test "registers offense for send with arguments" do
    assert_offense <<~RUBY
      test "calculates total" do
        result = order.send(:calculate_total, 100, 0.1)
        assert_equal 110, result
      end
    RUBY
  end

  test "registers offense for send nested inside block within test" do
    assert_offense <<~RUBY
      test "processes all orders" do
        orders.each do |order|
          order.send(:validate!)
        end
      end
    RUBY
  end

  test "allows calling methods directly" do
    assert_no_offense <<~RUBY
      test "processes payment" do
        order.checkout
        assert order.paid?
      end
    RUBY
  end

  test "allows send outside test blocks" do
    assert_no_offense <<~RUBY
      class PaymentTest < ActiveSupport::TestCase
        def helper_method
          object.send(:something)
        end
      end
    RUBY
  end

  test "allows receiverless send (method named send)" do
    assert_no_offense <<~RUBY
      test "sends notification" do
        send(:setup_data)
      end
    RUBY
  end
end
