require "test_helper"

class ControllerTestResponseAssertionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ControllerTestResponseAssertion

  CONTROLLER_TEST = "test/controllers/users_controller_test.rb"

  test "recognizes requests and response assertions explicitly qualified with self" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "creates" do
        self.post users_url
        self.assert_response :created
      end
    RUBY
  end

  test "recognizes safe navigation requests and response assertions on self" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "creates" do
        self&.post users_url
      end
    RUBY

    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "creates" do
        post users_url
        self&.assert_response :created
      end
    RUBY
  end

  test "allows a test block with no body at all" do
    assert_no_offense <<~RUBY
      class UsersControllerTest < ActionDispatch::IntegrationTest
        test "does nothing" do
        end
      end
    RUBY
  end

  test "registers offense for post without response assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create creates a user" do
        post users_url, params: { name: "John" }
        assert_equal 1, User.count
      end
    RUBY
  end

  test "registers offense for get without response assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "index lists users" do
        get users_url
        assert_equal 3, assigns(:users).size
      end
    RUBY
  end

  test "registers offense for delete without response assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "destroy removes user" do
        delete user_url(users(:one))
        assert_equal 0, User.count
      end
    RUBY
  end

  test "registers offense for put without response assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "update" do
        put user_url(users(:one)), params: { name: "Updated" }
      end
    RUBY
  end

  test "registers offense for patch without response assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "update" do
        patch user_url(users(:one)), params: { name: "Updated" }
        assert_equal "Updated", users(:one).reload.name
      end
    RUBY
  end

  test "allows post with assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create creates a user" do
        post users_url, params: { name: "John" }
        assert_response :created
        assert_equal 1, User.count
      end
    RUBY
  end

  test "allows post with assert_redirected_to" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create redirects" do
        post users_url, params: { name: "John" }
        assert_redirected_to user_path(User.last)
      end
    RUBY
  end

  test "allows test with no HTTP request" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "helper method works" do
        assert_equal "expected", helper_method
      end
    RUBY
  end

  test "allows response assertion after other code" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url
        user = User.last
        assert_response :created
      end
    RUBY
  end

  test "allows HTTP method with receiver" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "some test" do
        client.get "/api/users"
        assert_equal "ok", result
      end
    RUBY
  end

  test "allows request inside assert_difference with response assertion" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        assert_difference("User.count", 1) do
          post users_url, params: { name: "John" }
        end
        assert_response :created
      end
    RUBY
  end

  test "allows follow_redirect then assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create redirects and shows" do
        post users_url, params: { name: "John" }
        follow_redirect!
        assert_response :success
      end
    RUBY
  end

  test "registers offense when a later request has no response assertion" do
    offenses = assert_offense <<~RUBY, count: 1, file: CONTROLLER_TEST
      test "create then show" do
        post users_url
        assert_response :created
        get user_url(User.last)
      end
    RUBY

    assert_equal 4, offenses.first.location.line
  end

  test "registers offense when one response assertion follows two requests" do
    assert_offense <<~RUBY, count: 1, file: CONTROLLER_TEST
      test "create then show" do
        post users_url
        get user_url(User.last)
        assert_response :success
      end
    RUBY
  end

  test "recognizes an assigned request" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "show" do
        result = get user_url(users(:one))
        assert_equal "Bruno", result.name
      end
    RUBY
  end

  test "recognizes a request inside an ordinary block" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "show" do
        measure do
          get user_url(users(:one))
        end
      end
    RUBY
  end

  test "ignores requests inside definitions and deferred callables" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "builds helpers" do
        def request_later
          get users_url
        end

        def object.request_later
          post users_url
        end

        class Nested
          put users_url
        end

        module Helpers
          patch users_url
        end

        class << object
          delete users_url
        end

        first = -> { get users_url }
        second = lambda { post users_url }
        third = proc { put users_url }
        fourth = Proc.new { patch users_url }
      end
    RUBY
  end

  test "does not accept a response assertion hidden in a deferred callable" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "show" do
        get user_url(users(:one))
        callback = -> { assert_response :success }
      end
    RUBY
  end

  test "allows a request expected to raise" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "show rejects malformed input" do
        assert_raises(ActionController::BadRequest) do
          get user_url("invalid")
        end
      end
    RUBY
  end

  test "does not accept an unrelated assertion expected to raise after the request" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "show rejects an unrelated operation" do
        get user_url("invalid")
        assert_raises(RuntimeError) { unrelated_operation }
      end
    RUBY
  end

  test "allows a test block with an empty body" do
    assert_no_offense <<~RUBY, file: "test/controllers/users_controller_test.rb"
      class UsersControllerTest < ActionDispatch::IntegrationTest
        test "index" do
        end
      end
    RUBY
  end
end
