require "test_helper"

class BuilderMethodParenthesesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::BuilderMethodParentheses

  test "registers offense and corrects new without parentheses" do
    assert_correction(
      <<~RUBY,
        User.new name: "John"
      RUBY
      <<~RUBY
        User.new(name: "John")
      RUBY
    )
  end

  test "registers offense and corrects create with multiple keyword args" do
    assert_correction(
      <<~RUBY,
        User.create name: "John", email: "j@example.com"
      RUBY
      <<~RUBY
        User.create(name: "John", email: "j@example.com")
      RUBY
    )
  end

  test "registers offense and corrects find with positional arg" do
    assert_correction(
      <<~RUBY,
        User.find 1
      RUBY
      <<~RUBY
        User.find(1)
      RUBY
    )
  end

  test "registers offense and corrects find_by without parentheses" do
    assert_correction(
      <<~RUBY,
        User.find_by name: "John"
      RUBY
      <<~RUBY
        User.find_by(name: "John")
      RUBY
    )
  end

  test "registers offense and corrects permit without parentheses" do
    assert_correction(
      <<~RUBY,
        params.permit :name, :email
      RUBY
      <<~RUBY
        params.permit(:name, :email)
      RUBY
    )
  end

  test "registers offense and corrects expect without parentheses" do
    assert_correction(
      <<~RUBY,
        params.expect user: [ :name, :email ]
      RUBY
      <<~RUBY
        params.expect(user: [ :name, :email ])
      RUBY
    )
  end

  test "registers offense and corrects update with positional and keyword args" do
    assert_correction(
      <<~RUBY,
        User.update 1, name: "John"
      RUBY
      <<~RUBY
        User.update(1, name: "John")
      RUBY
    )
  end

  test "registers offense and corrects find_or_create_by with block" do
    assert_correction(
      <<~RUBY,
        User.find_or_create_by name: "John" do |user|
          user.email = "j@example.com"
        end
      RUBY
      <<~RUBY
        User.find_or_create_by(name: "John") do |user|
          user.email = "j@example.com"
        end
      RUBY
    )
  end

  test "registers offense and corrects receiver-less call" do
    assert_correction(
      <<~RUBY,
        find_by name: "John"
      RUBY
      <<~RUBY
        find_by(name: "John")
      RUBY
    )
  end

  test "registers offense and corrects assign_attributes" do
    assert_correction(
      <<~RUBY,
        user.assign_attributes name: "John"
      RUBY
      <<~RUBY
        user.assign_attributes(name: "John")
      RUBY
    )
  end

  test "registers offense and corrects destroy_by" do
    assert_correction(
      <<~RUBY,
        User.destroy_by name: "John"
      RUBY
      <<~RUBY
        User.destroy_by(name: "John")
      RUBY
    )
  end

  test "allows already parenthesized call" do
    assert_no_offense <<~RUBY
      User.create(name: "John")
    RUBY
  end

  test "allows call without arguments" do
    assert_no_offense <<~RUBY
      User.new
    RUBY
  end

  test "allows bang method without parentheses" do
    assert_no_offense <<~RUBY
      User.create! name: "John"
    RUBY
  end

  test "allows bang find_or_create_by without parentheses" do
    assert_no_offense <<~RUBY
      User.find_or_create_by! name: "John"
    RUBY
  end

  test "allows backslash continuation without parentheses" do
    assert_no_offense <<~'RUBY'
      User.create \
        name: "John"
    RUBY
  end

  test "allows method not in the list" do
    assert_no_offense <<~RUBY
      User.where active: true
    RUBY
  end

  test "allows unrelated method without parentheses" do
    assert_no_offense <<~RUBY
      puts "hello"
    RUBY
  end
end
