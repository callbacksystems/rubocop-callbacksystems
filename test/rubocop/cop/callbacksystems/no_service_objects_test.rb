require "test_helper"

class RuboCop::Cop::Callbacksystems::NoServiceObjectsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoServiceObjects

  test "registers offense for file in services directory" do
    assert_offense <<~RUBY, file: "app/services/order_processor.rb"
      class OrderProcessor
      end
    RUBY
  end

  test "registers offense for file in decorators directory" do
    assert_offense <<~RUBY, file: "app/decorators/user_decorator.rb"
      class UserDecorator
      end
    RUBY
  end

  test "registers offense for file in interactors directory" do
    assert_offense <<~RUBY, file: "app/interactors/create_order.rb"
      class CreateOrder
      end
    RUBY
  end

  test "registers offense for file in presenters directory" do
    assert_offense <<~RUBY, file: "app/presenters/user_presenter.rb"
      class UserPresenter
      end
    RUBY
  end

  test "registers offense for file in forms directory" do
    assert_offense <<~RUBY, file: "app/forms/registration_form.rb"
      class RegistrationForm
      end
    RUBY
  end

  test "registers offense for file in operations directory" do
    assert_offense <<~RUBY, file: "app/operations/checkout.rb"
      class Checkout
      end
    RUBY
  end

  test "registers offense for file in commands directory" do
    assert_offense <<~RUBY, file: "app/commands/send_email.rb"
      class SendEmail
      end
    RUBY
  end

  test "registers offense for file in queries directory" do
    assert_offense <<~RUBY, file: "app/queries/user_search.rb"
      class UserSearch
      end
    RUBY
  end

  test "registers offense for file in use_cases directory" do
    assert_offense <<~RUBY, file: "app/use_cases/place_order.rb"
      class PlaceOrder
      end
    RUBY
  end

  test "allows files in models directory" do
    assert_no_offense <<~RUBY, file: "app/models/order.rb"
      class Order
      end
    RUBY
  end

  test "allows files in controllers directory" do
    assert_no_offense <<~RUBY, file: "app/controllers/orders_controller.rb"
      class OrdersController
      end
    RUBY
  end

  test "allows files in lib directory" do
    assert_no_offense <<~RUBY, file: "lib/order_processor.rb"
      class OrderProcessor
      end
    RUBY
  end

  test "allows commands directory under lib (non-Rails gem)" do
    assert_no_offense <<~RUBY, file: "lib/my_gem/commands/run.rb"
      class MyGem::Commands::Run
      end
    RUBY
  end

  test "allows queries directory under lib (non-Rails gem)" do
    assert_no_offense <<~RUBY, file: "lib/queries/build.rb"
      class Queries::Build
      end
    RUBY
  end

  test "allows services directory at the top level (non-Rails)" do
    assert_no_offense <<~RUBY, file: "services/external_api.rb"
      class ExternalApi
      end
    RUBY
  end

  test "registers offense with absolute path under app/" do
    assert_offense <<~RUBY, file: "/home/user/project/app/services/order_processor.rb"
      class OrderProcessor
      end
    RUBY
  end

  test "registers an empty file in a forbidden directory" do
    assert_offense "", file: "app/services/placeholder.rb"
  end

  test "registers a comment-only file in a forbidden directory" do
    assert_offense "# placeholder\n", file: "app/queries/placeholder.rb"
  end

  test "allows an empty file" do
    assert_no_offense ""
  end
end
