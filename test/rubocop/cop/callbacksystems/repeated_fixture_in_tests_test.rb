require "test_helper"

class RuboCop::Cop::Callbacksystems::RepeatedFixtureInTestsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RepeatedFixtureInTests

  test "registers offense for same fixture in multiple tests" do
    offenses = assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates name" do
          user = users(:john)
          assert user.valid?
        end

        test "validates email" do
          user = users(:john)
          assert user.email.present?
        end
      end
    RUBY
    assert_equal 1, offenses.size
  end

  test "registers multiple offenses for fixture used in three tests" do
    offenses = assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test one" do
          user = users(:john)
        end

        test "test two" do
          user = users(:john)
        end

        test "test three" do
          user = users(:john)
        end
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "allows fixture used only once" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates name" do
          user = users(:john)
          assert user.valid?
        end

        test "validates email" do
          user = users(:jane)
          assert user.email.present?
        end
      end
    RUBY
  end

  test "allows different fixtures in different tests" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates john" do
          user = users(:john)
          assert user.valid?
        end

        test "validates jane" do
          user = users(:jane)
          assert user.valid?
        end
      end
    RUBY
  end

  test "allows fixtures in setup" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "validates name" do
          assert @user.valid?
        end

        test "validates email" do
          assert @user.email.present?
        end
      end
    RUBY
  end

  test "detects fixtures with different method names" do
    offenses = assert_offense <<~RUBY, file: "test/models/post_test.rb"
      class PostTest < ActiveSupport::TestCase
        test "test one" do
          post = posts(:first)
        end

        test "test two" do
          post = posts(:first)
        end
      end
    RUBY
    assert_equal 1, offenses.size
  end
end
