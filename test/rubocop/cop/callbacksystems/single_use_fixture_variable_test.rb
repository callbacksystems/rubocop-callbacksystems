require "test_helper"

class RuboCop::Cop::Callbacksystems::SingleUseFixtureVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable

  test "registers offense for fixture assigned but used only once" do
    assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid?
        end
      end
    RUBY
  end

  test "allows fixture used multiple times" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid?
          assert user.name.present?
        end
      end
    RUBY
  end

  test "allows inline fixture call" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          assert users(:john).valid?
        end
      end
    RUBY
  end

  test "does not apply to non-fixture assignments" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "creates user" do
          user = User.create!(name: "John")
          assert user.valid?
        end
      end
    RUBY
  end

  test "does not apply outside test blocks" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "validates user" do
          assert @user.valid?
        end
      end
    RUBY
  end

  test "registers offense for multiple single-use fixtures" do
    offenses = assert_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = users(:john)
          post = posts(:first)
          assert user.posts.include?(post)
        end
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "allows fixture used in loop" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = users(:john)
          3.times { user.touch }
        end
      end
    RUBY
  end

  test "detects various fixture method patterns" do
    assert_offense <<~RUBY, file: "test/models/post_test.rb"
      class PostTest < ActiveSupport::TestCase
        test "test categories" do
          category = categories(:tech)
          assert category.name
        end
      end
    RUBY
  end

  test "autocorrects single-use fixture variable" do
    original = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/user_test.rb"
  end

  test "autocorrects multiple single-use fixtures" do
    original = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = users(:john)
          post = posts(:first)
          assert user.posts.include?(post)
        end
      end
    RUBY

    corrected = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          assert users(:john).posts.include?(posts(:first))
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/user_test.rb"
  end
end
