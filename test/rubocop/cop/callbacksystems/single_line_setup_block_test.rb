require "test_helper"

class SingleLineSetupBlockTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleLineSetupBlock

  test "registers offense for single-line setup with do/end" do
    assert_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:bruno)
        end
      end
    RUBY
  end

  test "registers offense for single-line teardown with do/end" do
    assert_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        teardown do
          cleanup
        end
      end
    RUBY
  end

  test "accepts inline setup block" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        setup { @user = users(:bruno) }
      end
    RUBY
  end

  test "accepts multi-line setup with do/end" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:bruno)
          @account = accounts(:callback)
        end
      end
    RUBY
  end

  test "accepts multi-line teardown with do/end" do
    assert_no_offense(<<~RUBY)
      class UserTest < ActiveSupport::TestCase
        teardown do
          cleanup_users
          cleanup_accounts
        end
      end
    RUBY
  end

  test "accepts single statement spanning multiple lines" do
    assert_no_offense(<<~'RUBY')
      class UserTest < ActiveSupport::TestCase
        setup do
          @field = Form::Field::LinearScale.new \
            form: forms(:callback_intake),
            label: "Rating"
        end
      end
    RUBY
  end

  test "autocorrects single-line setup with do/end to braces" do
    original = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:bruno)
        end
      end
    RUBY

    corrected = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup { @user = users(:bruno) }
      end
    RUBY

    assert_correction original, corrected
  end

  test "autocorrects single-line teardown with do/end to braces" do
    original = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        teardown do
          cleanup
        end
      end
    RUBY

    corrected = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        teardown { cleanup }
      end
    RUBY

    assert_correction original, corrected
  end

  test "allows a setup block holding a comment, which braces could not keep" do
    assert_no_offense <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup do
          # keep this note
          @user = users(:bruno)
        end
      end
    RUBY
  end
end
