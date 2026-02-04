require "test_helper"

class TestMethodDefinitionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::TestMethodDefinition

  test "registers offense for def test_* method" do
    assert_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        def test_something
          assert true
        end
      end
    RUBY
  end

  test "registers offense for def setup" do
    assert_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        def setup
          @user = users(:bruno)
        end
      end
    RUBY
  end

  test "registers offense for def teardown" do
    assert_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        def teardown
          cleanup
        end
      end
    RUBY
  end

  test "accepts test block syntax" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "accepts setup block syntax" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:bruno)
        end
      end
    RUBY
  end

  test "accepts setup inline block syntax" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        setup { @user = users(:bruno) }
      end
    RUBY
  end

  test "accepts teardown block syntax" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        teardown do
          cleanup
        end
      end
    RUBY
  end

  test "accepts regular methods" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        def helper_method
        end
      end
    RUBY
  end
end
