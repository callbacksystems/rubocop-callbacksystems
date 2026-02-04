require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferManyTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferMany

  test "registers offense for size > 1" do
    assert_offense <<~RUBY
      users.size > 1
    RUBY
  end

  test "registers offense for length > 1" do
    assert_offense <<~RUBY
      users.length > 1
    RUBY
  end

  test "registers offense for count > 1" do
    assert_offense <<~RUBY
      users.count > 1
    RUBY
  end

  test "autocorrects size > 1 to many?" do
    assert_correction "users.size > 1", "users.many?"
  end

  test "autocorrects with method chain" do
    assert_correction "users.active.size > 1", "users.active.many?"
  end

  test "does not register offense for size > 0" do
    assert_no_offense <<~RUBY
      users.size > 0
    RUBY
  end

  test "does not register offense for size > 2" do
    assert_no_offense <<~RUBY
      users.size > 2
    RUBY
  end

  test "does not register offense for size == 1" do
    assert_no_offense <<~RUBY
      users.size == 1
    RUBY
  end

  test "does not register offense for size < 1" do
    assert_no_offense <<~RUBY
      users.size < 1
    RUBY
  end

  test "does not register offense for 1 > size" do
    assert_no_offense <<~RUBY
      1 > users.size
    RUBY
  end
end
