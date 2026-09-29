require "test_helper"

class RuboCop::Cop::Callbacksystems::TooManyInstanceVariablesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::TooManyInstanceVariables

  test "registers offense when private method has more than 2 instance variable assignments" do
    assert_offense <<~RUBY
      class Foo
        private
          def setup_request
            @user = find_user
            @account = find_account
            @permissions = load_permissions
          end
      end
    RUBY
  end

  test "allows public method with many instance variable assignments" do
    assert_no_offense <<~RUBY
      class FooController
        def show
          @user = find_user
          @account = find_account
          @permissions = load_permissions
        end
      end
    RUBY
  end

  test "allows method with 2 or fewer instance variable assignments" do
    assert_no_offense <<~RUBY
      def setup_request
        @user = find_user
        @account = find_account
      end
    RUBY
  end

  test "allows initialize with many instance variable assignments" do
    assert_no_offense <<~RUBY
      def initialize(user, account, permissions)
        @user = user
        @account = account
        @permissions = permissions
        @created_at = Time.current
      end
    RUBY
  end

  test "allows single instance variable assignment" do
    assert_no_offense <<~RUBY
      def set_user
        @user = find_user
      end
    RUBY
  end

  test "allows memoization pattern" do
    assert_no_offense <<~RUBY
      def user
        @user ||= find_user
      end
    RUBY
  end

  test "counts unique variables only" do
    assert_no_offense <<~RUBY
      def process
        @result = first_attempt
        @result = second_attempt if @result.nil?
      end
    RUBY
  end

  test "allows empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "does not flag class methods" do
    assert_no_offense <<~RUBY
      def self.configure
        @config = load_config
        @logger = setup_logger
        @cache = setup_cache
      end
    RUBY
  end

  test "registers offense for private method with too many ivars in nested class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            private
              def setup_request
                @user = find_user
                @account = find_account
                @permissions = load_permissions
              end
          end
      end
    RUBY
  end

  test "allows initialize with many ivars in private nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def initialize(user, account, permissions)
              @user = user
              @account = account
              @permissions = permissions
              @created_at = Time.current
            end
          end
      end
    RUBY
  end

  test "allows public method with many ivars in nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def process
              @user = find_user
              @account = find_account
              @permissions = load_permissions
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
                private
                  def setup
                    @one = 1
                    @two = 2
                    @three = 3
                  end
              end
          end
      end
    RUBY
  end

  test "allows a private method assigning fewer fields than the maximum" do
    assert_no_offense <<~RUBY
      class Report
        private
          def prepare
            @title = "one"
          end
      end
    RUBY
  end

  test "does not charge a private method for fields assigned in a nested class" do
    assert_no_offense <<~RUBY
      class Report
        private
          def prepare
            helper = Class.new do
              def initialize
                @one = 1
                @two = 2
                @three = 3
              end
            end
            helper.new
          end
      end
    RUBY
  end

  test "does not charge a private method for state assigned by class and module builder bodies" do
    assert_no_offense <<~RUBY
      class Report
        private
          def prepare
            @result = build
            Class.new do
              @one = 1
              @two = 2
              @three = 3
            end
            Module.new do
              @four = 4
              @five = 5
              @six = 6
            end
          end
      end
    RUBY
  end

  test "counts state assigned inside an ordinary block" do
    assert_offense <<~RUBY
      class Report
        private
          def prepare
            values.each do
              @one = 1
              @two = 2
              @three = 3
            end
          end
      end
    RUBY
  end

  test "counts a builder argument assignment before self changes" do
    assert_offense <<~RUBY
      class Report
        private
          def prepare
            @one = 1
            @two = 2
            Class.new(@three = parent) { @inner = build }
          end
      end
    RUBY
  end

  test "does not count state evaluated against another receiver" do
    assert_no_offense <<~RUBY
      class Report
        private
          def prepare(target)
            @one = 1
            @two = 2
            target.instance_eval do
              @three = 3
              @four = 4
              @five = 5
            end
          end
      end
    RUBY
  end

  test "counts state evaluated against the current self" do
    assert_offense <<~RUBY
      class Report
        private
          def prepare
            self.instance_eval do
              @one = 1
              @two = 2
              @three = 3
            end
          end
      end
    RUBY
  end

  test "does not attribute an anonymous class method to the outer private section" do
    assert_no_offense <<~RUBY
      class Report
        private
          Handler = Class.new do
            def prepare
              @one = 1
              @two = 2
              @three = 3
            end
          end
      end
    RUBY
  end
end
