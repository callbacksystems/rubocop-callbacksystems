require "test_helper"

class ControllerTestResponseAssertionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ControllerTestResponseAssertion

  CONTROLLER_TEST = "test/controllers/users_controller_test.rb"

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
end
