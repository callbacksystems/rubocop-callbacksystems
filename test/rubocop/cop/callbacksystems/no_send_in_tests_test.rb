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

  test "registers offense for send through safe navigation" do
    assert_offense <<~RUBY
      test "processes payment" do
        order&.send(:process_payment)
      end
    RUBY
  end

  test "allows send inside method definitions declared by a test" do
    assert_no_offense <<~RUBY
      test "installs helpers" do
        def helper
          object.send(:something)
        end

        def self.other_helper
          object.__send__(:something)
        end
      end
    RUBY
  end

  test "allows send inside deferred callable bodies" do
    assert_no_offense <<~RUBY
      test "builds callbacks" do
        callback = -> { object.send(:something) }
        proc { object.__send__(:something) }
        Proc.new { object.send(:something_else) }
      end
    RUBY
  end

  test "registers send in arguments evaluated while constructing a deferred callable" do
    assert_offense <<~RUBY, count: 3
      test "builds callbacks" do
        proc(object.send(:proc_name)) { deferred.send(:inside_proc) }
        Proc.new(object.__send__(:callable_name)) { deferred.send(:inside_new) }
        define_method(object.send(:method_name)) { deferred.send(:inside_method) }
      end
    RUBY
  end

  test "allows send inside methods defined by blocks" do
    assert_no_offense <<~RUBY
      test "defines methods" do
        define_method(:helper) { object.send(:something) }
        define_singleton_method(:other_helper) { object.__send__(:something) }
      end
    RUBY
  end

  test "allows send inside a nested class or module" do
    assert_no_offense <<~RUBY
      test "defines helpers" do
        class Helper
          object.send(:configure)

          def call
            object.__send__(:something)
          end
        end

        module Support
          object.send(:configure)
        end
      end
    RUBY
  end

  test "reports a call in a nested test only once" do
    assert_offense <<~RUBY, count: 1
      test "outer" do
        test "inner" do
          object.send(:something)
        end
      end
    RUBY
  end

  test "registers send in arguments evaluated by a nested test declaration" do
    assert_offense <<~RUBY, count: 1
      test "outer" do
        test(object.send(:test_name)) do
          object.__send__(:inside_test)
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

  test "allows a test block with an empty body" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "it works" do
        end
      end
    RUBY
  end
end
