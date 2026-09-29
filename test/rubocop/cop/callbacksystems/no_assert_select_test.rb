require "test_helper"

class NoAssertSelectTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAssertSelect

  test "registers offense for assert_select with selector" do
    assert_offense(<<~RUBY)
      assert_select "div.notice"
    RUBY
  end

  test "registers offense for assert_select with text option" do
    assert_offense(<<~RUBY)
      assert_select "h1", text: /Welcome/
    RUBY
  end

  test "registers offense for assert_select with count option" do
    assert_offense(<<~RUBY)
      assert_select "li", count: 5
    RUBY
  end

  test "registers offense for assert_select in block" do
    assert_offense(<<~RUBY, count: 2)
      assert_select "form" do
        assert_select "input[type=email]"
      end
    RUBY
  end

  test "registers offense for assert_select called explicitly on self" do
    assert_offense <<~RUBY
      self.assert_select "div.notice"
    RUBY
  end

  test "registers offense for assert_select safely navigated on self" do
    assert_offense <<~RUBY
      self&.assert_select "div.notice"
    RUBY
  end

  test "allows assert_response" do
    assert_no_offense(<<~RUBY)
      assert_response :success
    RUBY
  end

  test "allows assert_redirected_to" do
    assert_no_offense(<<~RUBY)
      assert_redirected_to dashboard_path
    RUBY
  end

  test "allows other assertions" do
    assert_no_offense(<<~RUBY)
      assert user.valid?
      assert_equal "John", user.name
      assert_includes users, john
    RUBY
  end

  test "allows assert_select with another receiver" do
    assert_no_offense(<<~RUBY)
      some_object.assert_select "div"
    RUBY
  end
end
