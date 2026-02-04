require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferExcludingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferExcluding

  test "registers offense for array minus single element array" do
    assert_offense <<~RUBY
      users - [admin]
    RUBY
  end

  test "autocorrects to excluding" do
    assert_correction "users - [admin]", "users.excluding(admin)"
  end

  test "autocorrects with method chain" do
    assert_correction "users.active - [admin]", "users.active.excluding(admin)"
  end

  test "autocorrects with complex element" do
    assert_correction "items - [items.first]", "items.excluding(items.first)"
  end

  test "does not register offense for multi-element array" do
    assert_no_offense <<~RUBY
      users - [admin, guest]
    RUBY
  end

  test "does not register offense for empty array" do
    assert_no_offense <<~RUBY
      users - []
    RUBY
  end

  test "does not register offense for variable subtraction" do
    assert_no_offense <<~RUBY
      users - excluded
    RUBY
  end

  test "does not register offense for numeric subtraction" do
    assert_no_offense <<~RUBY
      total - 1
    RUBY
  end
end
