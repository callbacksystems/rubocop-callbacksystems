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

  test "allows the Rack protocol on middleware" do
    assert_no_offense <<~RUBY
      class AuthenticationMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        end
      end
    RUBY
  end

  test "allows the Rack protocol when a class accepts an application" do
    assert_no_offense <<~RUBY
      class Pipeline
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        end
      end
    RUBY
  end

  test "does not give an anonymous class the outer Rack middleware exemption" do
    assert_offense <<~RUBY
      class AuthenticationMiddleware
        def initialize(app)
          @app = app
        end

        Handler = Class.new do
          def call(env)
            env
          end
        end
      end
    RUBY
  end

  test "still rejects a service object named Middleware when its argument is not a Rack environment" do
    assert_offense <<~RUBY
      class DeliveryMiddleware
        def call(order)
          deliver(order)
        end
      end
    RUBY
  end

  test "rejects a singleton call even when the class otherwise looks like Rack middleware" do
    assert_offense <<~RUBY, count: 2
      class AuthenticationMiddleware
        def initialize(app)
          @app = app
        end

        def self.call(env)
          new(env).call
        end

        class << self
          def call(env)
            new(env).call
          end
        end
      end
    RUBY
  end

  test "still rejects a top-level call method with a Rack-shaped argument" do
    assert_offense <<~RUBY
      def call(env)
      end
    RUBY
  end
end
