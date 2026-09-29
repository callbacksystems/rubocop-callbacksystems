require "test_helper"

class RuboCop::Cop::Callbacksystems::RepeatedFixtureInTestsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RepeatedFixtureInTests

  test "external_dependency_checksum follows the fixture files used to distinguish accessors from helpers" do
    assert_not_empty RuboCop::Cop::Callbacksystems::RepeatedFixtureInTests.new.external_dependency_checksum
  end

  test "registers offense for same fixture in multiple tests" do
    assert_offense <<~RUBY, count: 1, file: "test/models/user_test.rb"
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
  end

  test "registers multiple offenses for fixture used in three tests" do
    assert_offense <<~RUBY, count: 2, file: "test/models/user_test.rb"
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

  test "allows a fixture called twice within one test" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "name reads the fixture" do
          assert_equal users(:bruno).name, users(:bruno).reload.name
        end
      end
    RUBY
  end

  test "ignores fixture calls inside deferred callable and method bodies" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "builds the first callbacks" do
          -> { users(:bruno) }
          lambda { users(:bruno) }
          proc { _1; users(:bruno) }
          Proc.new { it; users(:bruno) }

          def callback
            users(:bruno)
          end

          define_method(:other_callback) { users(:bruno) }
        end

        test "builds the second callbacks" do
          -> { users(:bruno) }
          lambda { users(:bruno) }
          proc { _1; users(:bruno) }
          Proc.new { it; users(:bruno) }

          def callback
            users(:bruno)
          end

          define_method(:other_callback) { users(:bruno) }
        end
      end
    RUBY
  end

  test "does not attribute a nested test body to the test that declares it" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "declares another test" do
          test "reads the nested user" do
            users(:bruno)
          end
        end

        test "reads the outer user" do
          users(:bruno)
        end
      end
    RUBY
  end

  test "counts fixture calls in definition headers evaluated by each test" do
    assert_offense <<~RUBY, count: 1, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "opens the first singleton class" do
          class << users(:bruno)
          end
        end

        test "opens the second singleton class" do
          class << users(:bruno)
          end
        end
      end
    RUBY
  end

  test "counts fixtures in numbered and implicit it test blocks" do
    assert_offense <<~RUBY, count: 1, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test("reads with a numbered argument") { _1; users(:bruno) }
        test("reads with an implicit it argument") { it; users(:bruno) }
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

  test "groups semantically equal fixtures written with different symbol spellings" do
    assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates name" do
          users(:john)
        end

        test "validates email" do
          users(:"john")
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
    assert_offense <<~RUBY, count: 1, file: "test/models/post_test.rb"
      class PostTest < ActiveSupport::TestCase
        test "test one" do
          post = posts(:first)
        end

        test "test two" do
          post = posts(:first)
        end
      end
    RUBY
  end
  test "allows a test helper whose name reads like a fixture call" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test one" do
          sign_in_as(:john)
        end

        test "test two" do
          sign_in_as(:john)
        end
      end
    RUBY
  end

  test "allows a pluralized name the project declares no fixtures for" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test one" do
          widget = widgets(:first)
        end

        test "test two" do
          widget = widgets(:first)
        end
      end
    RUBY
  end

  test "detects a fixture set nested in a directory" do
    assert_offense <<~RUBY, count: 1, file: "test/models/webhook/delivery_test.rb"
      class Webhook::DeliveryTest < ActiveSupport::TestCase
        test "test one" do
          delivery = webhook_deliveries(:one)
        end

        test "test two" do
          delivery = webhook_deliveries(:one)
        end
      end
    RUBY
  end

  test "does not combine fixture calls from separate test classes" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class ActiveUserTest < ActiveSupport::TestCase
        test "reads the user" do
          users(:bruno)
        end
      end

      class ArchivedUserTest < ActiveSupport::TestCase
        test "reads the user" do
          users(:bruno)
        end
      end
    RUBY
  end

  test "does not combine fixture calls from separate anonymous test classes" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTestCases
        Active = Class.new(ActiveSupport::TestCase) do
          test "reads the active user" do
            users(:bruno)
          end
        end

        Archived = Class.new(ActiveSupport::TestCase) do
          test "reads the archived user" do
            users(:bruno)
          end
        end
      end
    RUBY
  end

  test "does not combine fixture calls from separate describe domains" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTestCases
        describe "active users" do
          test "reads the active user" do
            users(:bruno)
          end
        end

        describe "archived users" do
          test "reads the archived user" do
            users(:bruno)
          end
        end
      end
    RUBY
  end

  test "does not combine fixture calls from structurally identical reopened test classes" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "reads the user" do
          users(:bruno)
        end
      end

      class UserTest < ActiveSupport::TestCase
        test "reads the user" do
          users(:bruno)
        end
      end
    RUBY
  end

  test "distinguishes structurally identical test blocks in the same class" do
    assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "reads the user" do
          users(:bruno)
        end

        test "reads the user" do
          users(:bruno)
        end
      end
    RUBY
  end

  test "allows an empty file" do
    assert_no_offense ""
  end
end
