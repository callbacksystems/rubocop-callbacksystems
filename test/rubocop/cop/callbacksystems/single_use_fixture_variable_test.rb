require "test_helper"

class RuboCop::Cop::Callbacksystems::SingleUseFixtureVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable

  test "external_dependency_checksum follows the fixture files used to distinguish accessors from helpers" do
    assert_not_empty RuboCop::Cop::Callbacksystems::SingleUseFixtureVariable.new.external_dependency_checksum
  end

  test "allows a test block with no body" do
    assert_no_offense <<~RUBY
      test "does nothing" do
      end
    RUBY
  end

  test "allows an assignment whose value is not a call" do
    assert_no_offense <<~RUBY
      test "reads a literal" do
        name = "john"
        assert name
      end
    RUBY
  end

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
    assert_offense <<~RUBY, count: 2, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = users(:john)
          post = posts(:first)
          assert user.posts.include?(post)
        end
      end
    RUBY
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

  test "allows an immediately read fixture captured by a deferred callable" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid?
          callback = -> { use(user) }
        end
      end
    RUBY
  end

  test "allows a fixture lookup made inside an iterator" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates users" do
          users.each do
            user = users(:john)
          end
          assert user.valid?
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

  test "expands a shorthand keyword without changing its name" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "sends user" do
          user = users(:john)
          deliver(user:)
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        test "sends user" do
          deliver(user: users(:john))
        end
      end
    CORRECTED
  end

  test "parenthesizes a command-style fixture call when inlining it" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users :john
          assert user.valid?
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          assert users(:john).valid?
        end
      end
    CORRECTED
  end

  test "preserves a quoted fixture symbol when inlining" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:"john-doe")
          assert user.valid?
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          assert users(:"john-doe").valid?
        end
      end
    CORRECTED
  end

  test "allows a fixture local reassigned before its only read" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          user = replacement
          assert user.valid?
        end
      end
    RUBY
  end

  test "allows a fixture local rebound by pattern matching before its only read" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          case replacement
          in { user: }
          end
          assert user.valid?
        end
      end
    RUBY
  end

  test "still inlines when a nested block reassigns a shadowing local" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid?, items.all? { |user| user = replacement }
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          assert users(:john).valid?, items.all? { |user| user = replacement }
        end
      end
    CORRECTED
  end

  test "leaves multiple fixture lookups whose evaluation order would change for a human" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = users(:john)
          post = posts(:first)
          assert user.posts.include?(post)
        end
      end
    RUBY

    assert_offense source, count: 2, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "does not move a lookup past earlier work in the next statement" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert prepare, user.valid?
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "moves a lookup past an inert local read" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          expected = true
          user = users(:john)
          assert_equal expected, user.valid?
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          expected = true
          assert_equal expected, users(:john).valid?
        end
      end
    CORRECTED
  end

  test "does not make an unconditional lookup conditional" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          assert user.valid? if ready?
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "does not move a lookup into safely navigated arguments" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "notifies about user" do
          user = users(:john)
          notifier&.call(user)
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "allows a fixture local whose only written read runs repeatedly in a while loop" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "waits for user" do
          user = users(:john)
          while user.pending?
            wait
          end
        end
      end
    RUBY
  end

  test "leaves a same-line assignment and read for a human without overlapping corrections" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john); assert user
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "does not remove another statement sharing the assignment line" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          prepare; user = users(:john)
          assert user
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "leaves a fixture lookup separated from its read for a human" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "validates user" do
          user = users(:john)
          prepare_assertions
          assert user.valid?
        end
      end
    RUBY

    assert_offense source, file: "test/models/user_test.rb"
    assert_no_correction source, file: "test/models/user_test.rb"
  end

  test "allows a test helper whose name reads like a fixture call" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "test something" do
          user = sign_in_as(:john)
          assert user.valid?
        end
      end
    RUBY
  end

  test "indexes many fixture variables once" do
    assignments = 300.times.flat_map { [ "    user#{it} = users(:john)", "    assert user#{it}" ] }
    source = [ "test \"many users\" do", *assignments, "end", "" ].join("\n")

    assert_offense source, count: 300, file: "test/models/user_test.rb"
  end
end
