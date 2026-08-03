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
    assert_correction \
      "include C, A, B",
      "include A, B, C"
  end

  test "does not flag method calls with receiver" do
    assert_no_offense <<~RUBY
      config.include Helpers, Search
    RUBY
  end

  test "allows modules on separate lines, where the include order is written down" do
    assert_no_offense <<~RUBY
      class Order
        include Searchable
        include Confirmable
      end
    RUBY
  end

  test "sorting is offered but marked unsafe, since the ancestor chain follows the list" do
    assert_not RuboCop::Cop::Callbacksystems::OrderedMixinArguments.new(CopTestCase.default_config).safe_autocorrect?
  end

  test "sorts a list written across several lines onto one" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        include Searchable,
          Confirmable,
          Accessible
      RUBY
        include Accessible, Confirmable, Searchable
      CORRECTED
  end

  test "reports a list holding a comment but leaves it, since the note belongs to one module" do
    code = <<~RUBY
      include Searchable,
        # this one wins
        Confirmable
    RUBY

    assert_offense code
    assert_correction code, code
  end
end
