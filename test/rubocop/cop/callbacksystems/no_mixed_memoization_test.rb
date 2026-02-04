require "test_helper"

class RuboCop::Cop::Callbacksystems::NoMixedMemoizationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoMixedMemoization

  test "registers offense when memoization has statements before" do
    assert_offense <<~RUBY
      def user
        validate_params
        @user ||= User.find(params[:id])
      end
    RUBY
  end

  test "registers offense when memoization has statements after" do
    assert_offense <<~RUBY
      def user
        @user ||= User.find(params[:id])
        log_access
      end
    RUBY
  end

  test "registers offense when memoization is in the middle" do
    assert_offense <<~RUBY
      def process
        setup
        @cached ||= compute
        cleanup
      end
    RUBY
  end

  test "allows memoization as entire method body" do
    assert_no_offense <<~RUBY
      def user
        @user ||= User.find(params[:id])
      end
    RUBY
  end

  test "allows memoization with begin block" do
    assert_no_offense <<~RUBY
      def user
        @user ||= begin
          data = fetch_data
          process(data)
        end
      end
    RUBY
  end

  test "allows memoization with complex expression" do
    assert_no_offense <<~RUBY
      def user
        @user ||= User.find(params[:id]) || default_user
      end
    RUBY
  end

  test "allows non-memoization methods" do
    assert_no_offense <<~RUBY
      def process
        setup
        compute
        cleanup
      end
    RUBY
  end

  test "allows methods without memoization" do
    assert_no_offense <<~RUBY
      def user
        User.find(params[:id])
      end
    RUBY
  end

  test "allows regular or-assignment without instance variable" do
    assert_no_offense <<~RUBY
      def process
        setup
        value ||= default
        cleanup
      end
    RUBY
  end

  test "allows multiple memoizations in one method" do
    assert_no_offense <<~RUBY
      def token
        @expires_at ||= Time.current + expires_in
        @token ||= signed_id(expires_in: expires_in)
      end
    RUBY
  end

  test "registers offense when multiple memoizations mixed with other statements" do
    assert_offense <<~RUBY
      def token
        @expires_at ||= Time.current
        log_something
        @token ||= signed_id
      end
    RUBY
  end

  test "registers offense for mixed memoization in private nested class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def object
              validate_something
              @object ||= fetch_object
            end
          end
      end
    RUBY
  end

  test "allows pure memoization in private nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def object
              @object ||= fetch_object
            end
          end
      end
    RUBY
  end

  test "registers offense in deeply nested private class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Middle
            private
              class Inner
                def cached_value
                  setup
                  @cached_value ||= compute
                end
              end
          end
      end
    RUBY
  end

  test "allows memoization with begin block in nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def object
              @object ||= begin
                data = fetch_data
                process(data)
              end
            end
          end
      end
    RUBY
  end
end
