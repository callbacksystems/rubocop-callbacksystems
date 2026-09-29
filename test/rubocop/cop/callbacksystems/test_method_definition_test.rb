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

  test "allows a test-shaped method in a support class" do
    assert_no_offense <<~RUBY, file: "test/support/runner.rb"
      class Runner
        def test_connection
          connection.verify
        end

        def setup
          connection.prepare
        end
      end
    RUBY
  end

  test "allows a test-shaped method in a module" do
    assert_no_offense <<~RUBY
      module SharedTests
        def test_connection
          connection.verify
        end
      end
    RUBY
  end

  test "allows a test-shaped method owned by an anonymous class inside a test class" do
    assert_no_offense <<~RUBY
      class ContainerTest < ActiveSupport::TestCase
        Helper = Class.new do
          def test_connection
            connection.verify
          end
        end
      end
    RUBY
  end

  test "allows a top-level test-shaped method" do
    assert_no_offense <<~RUBY
      def test_connection
        connection.verify
      end
    RUBY
  end
end
