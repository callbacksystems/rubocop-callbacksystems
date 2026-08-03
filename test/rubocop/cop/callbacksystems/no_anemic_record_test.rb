require "test_helper"

class RuboCop::Cop::Callbacksystems::NoAnemicRecordTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAnemicRecord

  test "registers offense for a hash returned by one method and reached into by others" do
    offenses = assert_offense <<~'RUBY'
      class Billing
        private
          def context
            { account: account, plan: plan, seats: seats }
          end

          def price
            context[:plan].price * context[:seats]
          end

          def label
            "#{context[:account].name} (#{context[:plan].name})"
          end
      end
    RUBY
    assert_includes offenses.first.message, "carries `account, plan, seats`"
    assert_includes offenses.first.message, "2 methods reach into its keys"
  end

  test "registers offense when the keys are read with fetch" do
    assert_offense <<~RUBY
      class Billing
        private
          def context
            { account: account, plan: plan, seats: seats }
          end

          def price
            context.fetch(:plan).price * context.fetch(:seats)
          end

          def owner
            context.fetch(:account).owner
          end
      end
    RUBY
  end

  test "registers offense for a hash held in an instance variable" do
    assert_offense <<~RUBY
      class Billing
        def initialize(account, plan, seats)
          @context = { account: account, plan: plan, seats: seats }
        end

        private
          def price
            @context[:plan].price * @context[:seats]
          end

          def owner
            @context[:account].owner
          end
      end
    RUBY
  end

  test "allows a hash whose keys only one method reaches into" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { account: account, plan: plan, seats: seats }
          end

          def price
            context[:plan].price * context[:seats]
          end
      end
    RUBY
  end

  test "allows a hash of fewer keys than the threshold" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { plan: plan, seats: seats }
          end

          def price
            context[:plan].price
          end

          def label
            context[:seats].to_s
          end
      end
    RUBY
  end

  test "allows a hash handed straight to a call, which is a value rather than a concept" do
    assert_no_offense <<~RUBY
      class Billing
        def charge
          gateway.submit(account: account, plan: plan, seats: seats)
        end
      end
    RUBY
  end

  test "allows a hash carrying a callable, which makes it an object already" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { account: account, plan: plan, price: -> { plan.price } }
          end

          def total
            context[:price].call
          end

          def label
            context[:account].name
          end
      end
    RUBY
  end

  test "allows a hash built from a double splat, whose shape is not its own" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { account: account, plan: plan, **defaults }
          end

          def price
            context[:plan].price
          end

          def owner
            context[:account].owner
          end
      end
    RUBY
  end

  test "allows reaches sharing a single key with the hash, which is a coincidence of vocabulary" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { account: account, plan: plan, seats: seats }
          end

          def owner
            options[:account].owner
          end

          def label
            settings[:account].to_s
          end
      end
    RUBY
  end

  test "gives the reaches to the hash whose keys match them best" do
    offenses = assert_offense <<~RUBY
      class Billing
        private
          def wide
            { account: account, plan: plan, seats: seats, region: region }
          end

          def narrow
            { account: account, plan: plan, seats: seats }
          end

          def price
            narrow[:plan].price * narrow[:seats]
          end

          def owner
            narrow[:account].owner
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "carries `account, plan, seats`"
  end

  test "allows a hash whose keys are only reached inside the literal itself" do
    assert_no_offense <<~RUBY
      class Billing
        private
          def context
            { account: defaults[:account], plan: defaults[:plan], seats: defaults[:seats] }
          end
      end
    RUBY
  end

  test "registers offense for a frozen hash assigned to a constant" do
    assert_offense <<~'RUBY'
      class Billing
        SHAPE = { open: "{", close: "}", items: :children }.freeze

        private
          def wrap(inner)
            "#{SHAPE[:open]} #{inner} #{SHAPE[:close]}"
          end

          def items_of(node)
            node.public_send(SHAPE[:items])
          end
      end
    RUBY
  end
end
