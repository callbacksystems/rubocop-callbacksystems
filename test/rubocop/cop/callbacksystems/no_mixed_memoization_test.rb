require "test_helper"

class RuboCop::Cop::Callbacksystems::NoMixedMemoizationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoMixedMemoization

  test "allows memoization wrapped in begin and rescue" do
    assert_no_offense <<~RUBY
      def user
        begin
          @user ||= load_user
        rescue StandardError
          nil
        end
      end
    RUBY
  end

  test "registers offense for memoization followed by a bare return" do
    assert_offense <<~RUBY
      def user
        @user ||= load_user
        return
      end
    RUBY
  end

  test "allows a method with no body at all" do
    assert_no_offense <<~RUBY
      def user
      end
    RUBY
  end

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

  test "ignores memoization in nested lexical scopes" do
    assert_no_offense <<~RUBY
      def build
        def nested
          @nested ||= load_nested
        end

        object.define_singleton_method(:cached) do
          @cached ||= load_cached
        end

        class Nested
          @class_value ||= load_class_value
        end

        module Helpers
          @module_value ||= load_module_value
        end

        class << self
          @singleton_value ||= load_singleton_value
        end

        finish
      end
    RUBY
  end

  test "sees memoization evaluated while a nested singleton method receiver opens" do
    assert_offense <<~RUBY
      def build
        prepare
        def (@target ||= load_target).run; end
      end
    RUBY
  end

  test "ignores memoization in deferred callables" do
    assert_no_offense <<~RUBY
      def callbacks
        first = -> { @first ||= load_first }
        second = lambda { @second ||= load_second }
        third = proc { @third ||= load_third }
        fourth = Proc.new { @fourth ||= load_fourth }
        [first, second, third, fourth]
      end
    RUBY
  end

  test "ignores memoization when a deferred callable is the whole method body" do
    assert_no_offense <<~RUBY
      def callback
        -> { @value ||= load_value }
      end
    RUBY
  end

  test "ignores memoization when a nested lexical scope is the whole method body" do
    assert_no_offense <<~RUBY
      def build
        class Nested
          @value ||= load_value
        end
      end
    RUBY
  end

  test "still sees memoization in an immediately executing block" do
    assert_offense <<~RUBY
      def user
        measure { @user ||= load_user }
        report
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

  test "allows multiple memoizations wrapped in an explicit begin" do
    assert_no_offense <<~RUBY
      def token
        begin
          @expires_at ||= Time.current + expires_in
          @token ||= signed_id(expires_in: expires_in)
        end
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

  test "allows memoization followed by a read of the same field" do
    assert_no_offense <<~RUBY
      def user
        @user ||= load_user
        @user
      end
    RUBY
  end

  test "allows memoization followed by an explicit return of the same field" do
    assert_no_offense <<~RUBY
      def user
        @user ||= load_user
        return @user
      end
    RUBY
  end

  test "allows memoization and its field return wrapped in an explicit begin" do
    assert_no_offense <<~RUBY
      def user
        begin
          @user ||= load_user
          @user
        end
      end
    RUBY
  end

  test "allows memoization through nested transparent parentheses" do
    assert_no_offense <<~RUBY
      def user
        ((@user ||= load_user))
      end
    RUBY
  end

  test "allows conditional memoization through nested transparent parentheses" do
    assert_no_offense <<~RUBY
      def user
        ((@user ||= load_user if ready?))
      end
    RUBY
  end

  test "allows a memoized method whose body a rescue closes" do
    assert_no_offense <<~RUBY
      class Report
        def user
          @user ||= load_user
        rescue Timeout::Error
          nil
        end
      end
    RUBY
  end

  test "allows a method holding an empty begin block" do
    assert_no_offense <<~RUBY
      class Report
        def user
          begin
          end
        end
      end
    RUBY
  end

  test "unwraps transparent expressions deeper than Ruby's call stack" do
    memoization = RuboCop::AST::Node.new(:or_asgn, [ RuboCop::AST::Node.new(:ivasgn, [ :@value ]),
      RuboCop::AST::SendNode.new(:send, [ nil, :load_value ]) ])
    body = 5_000.times.reduce(memoization) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }
    expression = RuboCop::Cop::Callbacksystems::NoMixedMemoization::MemoizationBody::TransparentExpression.new(body)

    assert_same memoization, expression.value
  end
end
