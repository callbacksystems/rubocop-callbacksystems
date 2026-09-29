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

  test "autocorrects preserving call arguments and block parameters" do
    assert_correction <<~RUBY, <<~CORRECTED
      class UserTest < ActiveSupport::TestCase
        setup(:before_setup) do |test_case|
          test_case.prepare
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        setup(:before_setup) { |test_case| test_case.prepare }
      end
    CORRECTED
  end

  test "leaves a body carrying a heredoc for a human" do
    assert_uncorrectable_offense <<~RUBY
      class QueryTest < ActiveSupport::TestCase
        setup do
          @query = <<~SQL
            select 1
          SQL
        end
      end
    RUBY
  end

  test "autocorrects implicit and numbered block parameters" do
    assert_correction <<~RUBY, <<~CORRECTED
      setup do
        prepare(it)
      end
    RUBY
      setup { prepare(it) }
    CORRECTED

    assert_correction <<~RUBY, <<~CORRECTED
      teardown do
        cleanup(_1)
      end
    RUBY
      teardown { cleanup(_1) }
    CORRECTED
  end

  test "autocorrects command-style arguments without changing which call owns the block" do
    assert_correction <<~RUBY, <<~CORRECTED
      class UserTest < ActiveSupport::TestCase
        setup helper(:before_setup) do |test_case|
          test_case.prepare(:records)
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        setup(helper(:before_setup)) { |test_case| test_case.prepare(:records) }
      end
    CORRECTED
  end

  test "autocorrects every command-style argument inside the new argument list" do
    assert_correction <<~RUBY, <<~CORRECTED
      class UserTest < ActiveSupport::TestCase
        setup helper(:before_setup), after: callback do
          prepare(:records)
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        setup(helper(:before_setup), after: callback) { prepare(:records) }
      end
    CORRECTED
  end

  test "moves a command-style setup comment behind the compact block" do
    assert_correction <<~RUBY, <<~CORRECTED
      class UserTest < ActiveSupport::TestCase
        setup helper(:before_setup) do # prepares the fixture owner
          prepare(:records)
        end
      end
    RUBY
      class UserTest < ActiveSupport::TestCase
        setup(helper(:before_setup)) { prepare(:records) } # prepares the fixture owner
      end
    CORRECTED
  end

  test "leaves a block with several comments unchanged" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup helper(:before_setup) do # prepares the fixture owner
          prepare(:records) # keeps the records ready
        end
      end
    RUBY

    assert_offense source
    assert_no_correction source
  end

  test "leaves a tooling directive in place" do
    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup do # :nocov:
          prepare(:records)
        end
      end
    RUBY

    assert_offense source
    assert_no_correction source
  end

  test "leaves a multiline command unchanged until its argument layout can be preserved" do
    assert_uncorrectable_offense <<~RUBY
      class UserTest < ActiveSupport::TestCase
        setup helper(
          :before_setup
        ) do
          prepare(:records)
        end
      end
    RUBY
  end

  test "allows a setup block with an empty body" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
        end
      end
    RUBY
  end
end
