require "test_helper"

class ControllerTestResponseFirstAssertionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ControllerTestResponseFirstAssertion

  CONTROLLER_TEST = "test/controllers/users_controller_test.rb"

  test "registers offense for assert_equal before assert_response" do
    offenses = assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url, params: { name: "John" }
        assert_equal 1, User.count
        assert_response :created
      end
    RUBY

    assert_includes offenses.first.message, "assert_equal"
  end

  test "registers offense for bare assert before assert_response" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url, params: { name: "John" }
        user = User.last
        assert user.present?
        assert_response :created
      end
    RUBY
  end

  test "registers offense for refute before assert_response" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url
        refute User.empty?
        assert_response :created
      end
    RUBY
  end

  test "registers offense for assert_difference wrapping request then assert_equal before assert_response" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        assert_difference("User.count", 1) do
          post users_url, params: { name: "John" }
        end
        assert_equal "John", User.last.name
        assert_response :created
      end
    RUBY
  end

  test "allows assert_response as first assertion" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url, params: { name: "John" }
        assert_response :created
        assert_equal 1, User.count
      end
    RUBY
  end

  test "allows assert_redirected_to as first assertion" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create redirects" do
        post users_url, params: { name: "John" }
        assert_redirected_to users_path
      end
    RUBY
  end

  test "allows non-assertion code between request and response assertion" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url, params: { name: "John" }
        user = User.last
        assert_response :created
        assert_equal "John", user.name
      end
    RUBY
  end

  test "allows follow_redirect then assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create redirects" do
        post users_url, params: { name: "John" }
        follow_redirect!
        assert_response :success
      end
    RUBY
  end

  test "allows test with no HTTP request" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "helper" do
        assert_equal "expected", helper_method
      end
    RUBY
  end

  test "allows assert_difference wrapping request then assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        assert_difference("User.count", 1) do
          post users_url, params: { name: "John" }
        end
        assert_response :created
      end
    RUBY
  end

  test "allows multiple requests each followed by response assertion" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create then show" do
        post users_url, params: { name: "John" }
        assert_response :created
        get user_url(User.last)
        assert_response :success
      end
    RUBY
  end

  test "allows assert_enqueued_emails before assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create sends email" do
        post users_url, params: { name: "John" }
        assert_enqueued_emails 1
        assert_response :created
      end
    RUBY
  end

  test "allows assert_enqueued_jobs before assert_redirected_to" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create enqueues job" do
        post users_url, params: { name: "John" }
        assert_enqueued_jobs 1
        assert_redirected_to users_path
      end
    RUBY
  end

  test "allows assert_no_enqueued_emails before assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create for unknown user sends no mail" do
        post passwords_url, params: { email_address: "missing@example.com" }
        assert_no_enqueued_emails
        assert_redirected_to new_session_path
      end
    RUBY
  end

  test "allows multiple side-effect assertions before assert_response" do
    assert_no_offense <<~RUBY, file: CONTROLLER_TEST
      test "create enqueues job and email" do
        post users_url, params: { name: "John" }
        assert_enqueued_jobs 1
        assert_enqueued_emails 1
        assert_response :created
      end
    RUBY
  end

  test "registers offense for assert_equal even after side-effect assertion" do
    assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "create" do
        post users_url, params: { name: "John" }
        assert_enqueued_emails 1
        assert_equal 1, User.count
        assert_response :created
      end
    RUBY
  end

  test "registers offense for get with assert_includes before assert_response" do
    offenses = assert_offense <<~RUBY, file: CONTROLLER_TEST
      test "index" do
        get users_url
        assert_includes response.body, "John"
        assert_response :success
      end
    RUBY

    assert_includes offenses.first.message, "assert_includes"
  end
end
