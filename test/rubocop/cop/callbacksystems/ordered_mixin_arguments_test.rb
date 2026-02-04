require "test_helper"

class RuboCop::Cop::Callbacksystems::OrderedMixinArgumentsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::OrderedMixinArguments

  test "registers offense for unsorted include arguments" do
    assert_offense <<~RUBY
      include Searchable, Confirmable, Accessible
    RUBY
  end

  test "registers offense for unsorted extend arguments" do
    assert_offense <<~RUBY
      extend Searchable, Accessible
    RUBY
  end

  test "registers offense for unsorted prepend arguments" do
    assert_offense <<~RUBY
      prepend C, B, A
    RUBY
  end

  test "allows sorted include arguments" do
    assert_no_offense <<~RUBY
      include Accessible, Confirmable, Searchable
    RUBY
  end

  test "allows single include argument" do
    assert_no_offense <<~RUBY
      include Searchable
    RUBY
  end

  test "allows separate include lines" do
    assert_no_offense <<~RUBY
      include Searchable
      include Confirmable
    RUBY
  end

  test "allows namespaced modules sorted by full name" do
    assert_no_offense <<~RUBY
      include Account::Billable, User::Authenticatable
    RUBY
  end

  test "registers offense for unsorted namespaced modules" do
    assert_offense <<~RUBY
      include User::Authenticatable, Account::Billable
    RUBY
  end

  test "autocorrects unsorted arguments" do
    assert_correction(
      "include C, A, B",
      "include A, B, C"
    )
  end

  test "does not flag method calls with receiver" do
    assert_no_offense <<~RUBY
      config.include Helpers, Search
    RUBY
  end
end
