require "test_helper"

class NoCommentsInTestClassBodyTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoCommentsInTestClassBody

  test "registers offense for comment at class body level in test file" do
    offenses = assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # This is a bad comment
        setup do
          @user = users(:john)
        end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Avoid comments in test class body"
  end

  test "no offense for comment inside test block" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates name" do
          # This comment inside test is ok
          assert user.valid?
        end
      end
    RUBY
  end

  test "no offense for comment inside setup block" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
          # Setting up user
          @user = users(:john)
        end
      end
    RUBY
  end

  test "no offense for comment inside method" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        def helper_method
          # Comment inside method is ok
          do_something
        end
      end
    RUBY
  end

  test "no offense in non-test files" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User
        # This comment is fine in non-test file
        def process
        end
      end
    RUBY
  end

  test "no offense in mailer previews" do
    assert_no_offense <<~RUBY, file: "test/mailers/previews/user_mailer_preview.rb"
      class UserMailerPreview < ActionMailer::Preview
        # Preview email for welcome
        def welcome
          UserMailer.welcome(User.first)
        end
      end
    RUBY
  end

  test "no offense for placeholder comment in empty test class" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # test "the truth" do
        #   assert true
        # end
      end
    RUBY
  end
end
