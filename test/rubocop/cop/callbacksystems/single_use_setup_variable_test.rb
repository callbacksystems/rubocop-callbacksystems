require "test_helper"

class RuboCop::Cop::Callbacksystems::SingleUseSetupVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleUseSetupVariable

  test "registers offense for setup instance variable used in only one test" do
    offenses = assert_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_includes offenses.first.message, "@order"
  end

  test "no offense when setup variable is used in multiple tests" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "order has items" do
          assert @order.items.any?
        end
      end
    RUBY
  end

  test "no offense when setup has no instance variables" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          travel_to Time.zone.now
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "registers offense for each single-use variable independently" do
    offenses = assert_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY

    assert_equal 2, offenses.size
  end

  test "registers offense for variable used in zero tests" do
    offenses = assert_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "something" do
          assert true
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_includes offenses.first.message, "@order"
    assert_includes offenses.first.message, "not used"
  end

  test "handles multiple setup blocks" do
    offenses = assert_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        setup do
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY

    assert_equal 2, offenses.size
  end

  test "does not flag ivar used via a helper method called from tests" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "is admin" do
          assert_admin
        end

        test "is active" do
          assert_admin
        end

        private
          def assert_admin
            assert @user.admin?
          end
      end
    RUBY
  end

  test "skips abstract test base classes that directly inherit Rails test bases" do
    assert_no_offense <<~RUBY, file: "test/integration_test.rb"
      class IntegrationTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:admin)
        end
      end
    RUBY
  end

  test "does not flag ivar used elsewhere in the same setup block" do
    assert_no_offense <<~RUBY, file: "test/cli_test.rb"
      class CliTest < ActiveSupport::TestCase
        setup do
          @secrets_dir = Dir.mktmpdir
          PGBOX.stubs(:secrets_path).returns(File.join(@secrets_dir, ".pgbox/secrets"))
          FileUtils.mkdir_p(File.join(@secrets_dir, ".pgbox"))
        end

        teardown do
          FileUtils.rm_rf(@secrets_dir)
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "autocorrects a single-use variable by inlining it and removing the setup block" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order is valid" do
          assert orders(:one).valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects an unused variable by removing the setup block" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "something" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "something" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects a single-use variable while keeping a setup block with other statements" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          travel_to Time.zone.now
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          travel_to Time.zone.now
        end

        test "order is valid" do
          assert orders(:one).valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects single-use variables across multiple setup blocks" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        setup do
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order is valid" do
          assert orders(:one).valid?
        end

        test "user is valid" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects every variable in a setup block without leaving it empty" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order is valid" do
          assert orders(:one).valid?
        end

        test "user is valid" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "removes only the cleared lines when one variable in the setup block stays" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
          assert @user.persisted?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "order is valid" do
          assert orders(:one).valid?
        end

        test "user is valid" do
          assert @user.valid?
          assert @user.persisted?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the value is not a primary expression" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one) || build_order
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the variable is referenced more than once in the test" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
          assert @order.persisted?
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the reference is inside an iterator" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "touches the order" do
          3.times { @order.touch }
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end
end
