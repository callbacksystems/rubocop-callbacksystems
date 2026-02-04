require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferMethodOverVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferMethodOverVariable

  test "registers offense when variable name matches method call" do
    assert_offense <<~RUBY
      account = user.account
    RUBY
  end

  test "registers offense for instance variable receiver" do
    assert_offense <<~RUBY
      plan = @account.plan
    RUBY
  end

  test "allows chain receiver - delegate does not apply" do
    assert_no_offense <<~RUBY
      length = answer.value.to_s.length
    RUBY
  end

  test "allows when receiver is a method parameter" do
    assert_no_offense <<~RUBY
      def process(user)
        account = user.account
      end
    RUBY
  end

  test "allows when receiver is a block parameter" do
    assert_no_offense <<~RUBY
      users.each do |user|
        account = user.account
      end
    RUBY
  end

  test "allows different variable name than method" do
    assert_no_offense <<~RUBY
      user_account = user.account
    RUBY
  end

  test "allows transformation with different name" do
    assert_no_offense <<~RUBY
      formatted_date = date.strftime("%Y-%m-%d")
    RUBY
  end

  test "allows filtering with different name" do
    assert_no_offense <<~RUBY
      active_users = users.select(&:active?)
    RUBY
  end

  test "allows aggregation with different name" do
    assert_no_offense <<~RUBY
      total = items.sum(&:price)
    RUBY
  end

  test "allows assignment in if condition" do
    assert_no_offense <<~RUBY
      if user = find_user
        user.activate
      end
    RUBY
  end

  test "allows assignment in unless condition" do
    assert_no_offense <<~RUBY
      unless error = validate
        proceed
      end
    RUBY
  end

  test "allows finder in if condition" do
    assert_no_offense <<~RUBY
      if locale = I18n.find_locale(params[:locale])
        set_locale(locale)
      end
    RUBY
  end

  test "registers offense for find_x pattern" do
    assert_offense <<~RUBY
      user = find_user
    RUBY
  end

  test "registers offense for get_x pattern" do
    assert_offense <<~RUBY
      user = get_user
    RUBY
  end

  test "registers offense for fetch_x pattern" do
    assert_offense <<~RUBY
      config = fetch_config
    RUBY
  end

  test "registers offense for load_x pattern" do
    assert_offense <<~RUBY
      data = load_data
    RUBY
  end

  test "registers offense for Class.find pattern" do
    assert_offense <<~RUBY
      user = User.find(id)
    RUBY
  end

  test "registers offense for Class.find_by pattern" do
    assert_offense <<~RUBY
      order = Order.find_by(number: number)
    RUBY
  end

  test "registers offense for namespaced Class.find pattern" do
    assert_offense <<~RUBY
      payment_method = PaymentMethod.find(id)
    RUBY
  end

  test "allows Class.find with different variable name" do
    assert_no_offense <<~RUBY
      current_user = User.find(id)
    RUBY
  end

  test "allows finder with different variable name" do
    assert_no_offense <<~RUBY
      admin = find_user
    RUBY
  end

  test "allows block variables" do
    assert_no_offense <<~RUBY
      items.each { |item| process(item) }
    RUBY
  end

  test "allows non-send assignments" do
    assert_no_offense <<~RUBY
      count = 0
    RUBY
  end

  test "allows string assignments" do
    assert_no_offense <<~RUBY
      name = "John"
    RUBY
  end

  test "allows array assignments" do
    assert_no_offense <<~RUBY
      items = [1, 2, 3]
    RUBY
  end

  test "allows hash assignments" do
    assert_no_offense <<~RUBY
      options = { timeout: 30 }
    RUBY
  end
end
