require "test_helper"

class NoCommentsInTestClassBodyTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoCommentsInTestClassBody

  test "allows a file that is not a test file" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User
        # a note
        def name; end
      end
    RUBY
  end

  test "allows a test file holding no class at all" do
    assert_no_offense <<~RUBY
      # a note
      value = 1
    RUBY
  end

  test "registers offense for comment at class body level in test file" do
    offenses = assert_offense <<~RUBY, count: 1, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # This is a bad comment
        setup do
          @user = users(:john)
        end
      end
    RUBY

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

  test "retires a method scope before assigning a later class body comment" do
    assert_offense <<~RUBY, count: 1, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        def helper_method
          # This comment belongs to the helper.
          do_something
        end

        # This comment belongs to the test class.
        test "works" do
          assert true
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

  test "reports without a fix, since removing a comment is the author's call" do
    assert_uncorrectable_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # This is a bad comment
        setup do
          @user = users(:john)
        end
      end
    RUBY
  end

  test "reports each of several stacked comments" do
    assert_offense <<~RUBY, count: 2, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # First comment
        # Second comment
        setup do
          @user = users(:john)
        end
      end
    RUBY
  end

  test "allows a directive in the class body, which another cop reads" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        # rubocop:disable Metrics/AbcSize
        test "validates name" do
          assert true
        end
        # rubocop:enable Metrics/AbcSize
      end
    RUBY
  end

  test "allows a class body comment in a support class" do
    assert_no_offense <<~RUBY, file: "test/support/fake_gateway.rb"
      class FakeGateway
        # Deliberately emulates a timeout.
        def call; end
      end
    RUBY
  end

  test "allows a comment in a support class nested inside a test class" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        class FakeGateway
          # Deliberately emulates a timeout.
          def call; end
        end

        test "works" do
          assert true
        end
      end
    RUBY
  end

  test "reports only the direct comment of every deeply nested test class" do
    depth = 200
    source = [
      depth.times.map { "#{"  " * it}class Level#{it}Test\n#{"  " * (it + 1)}# level #{it}" },
      "#{"  " * depth}test \"bottom\" do\n#{"  " * (depth + 1)}assert true\n#{"  " * depth}end",
      depth.times.reverse_each.map { "#{"  " * it}end" }
    ].flatten.join("\n") << "\n"

    assert_offense source, count: depth, file: "test/models/deep_test.rb"
  end

  test "reports a trailing comment in the class body" do
    assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        include AuthHelpers # trailing comment
        test "validates name" do
          assert true
        end
      end
    RUBY
  end

  test "allows a comment in a source the parser was given no path for" do
    assert_no_offense <<~RUBY, file: nil
      class UserTest < ActiveSupport::TestCase
        # a note
        test "validates name" do
          assert true
        end
      end
    RUBY
  end
end
