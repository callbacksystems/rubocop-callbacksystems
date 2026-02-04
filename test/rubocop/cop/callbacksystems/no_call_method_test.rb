require "test_helper"

class RuboCop::Cop::Callbacksystems::NoCallMethodTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoCallMethod

  test "registers offense for instance method named call" do
    assert_offense <<~RUBY
      class OrderProcessor
        def call
        end
      end
    RUBY
  end

  test "registers offense for class method named call" do
    assert_offense <<~RUBY
      class OrderProcessor
        def self.call
        end
      end
    RUBY
  end

  test "registers offense for call in class << self block" do
    assert_offense <<~RUBY
      class OrderProcessor
        class << self
          def call
          end
        end
      end
    RUBY
  end

  test "allows other method names" do
    assert_no_offense <<~RUBY
      class Order
        def process
        end

        def self.create_from_cart
        end
      end
    RUBY
  end

  test "allows methods containing call but not named call" do
    assert_no_offense <<~RUBY
      class Webhook
        def call_external_api
        end

        def callback
        end
      end
    RUBY
  end
end
