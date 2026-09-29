require "test_helper"

class RuboCop::Cop::Callbacksystems::TooManyLocalVariablesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::TooManyLocalVariables

  test "registers offense when method has more than 3 local variable assignments" do
    assert_offense <<~RUBY
      def process
        user = find_user
        account = user.account
        plan = account.plan
        features = plan.features
      end
    RUBY
  end

  test "allows method with 3 or fewer local variable assignments" do
    assert_no_offense <<~RUBY
      def process
        user = find_user
        account = user.account
        plan = account.plan
      end
    RUBY
  end

  test "allows method without local variable assignments" do
    assert_no_offense <<~RUBY
      def process
        find_user.account.plan
      end
    RUBY
  end

  test "counts unique variables only" do
    assert_no_offense <<~RUBY
      def process
        result = first_attempt
        result = second_attempt if result.nil?
        result = third_attempt if result.nil?
        result
      end
    RUBY
  end

  test "counts names bound by patterns together with ordinary assignments" do
    assert_offense <<~RUBY
      def process(input)
        user = find_user
        input => { user:, account:, plan:, features: }
      end
    RUBY
  end

  test "does not count attribute assignments" do
    assert_no_offense <<~RUBY
      def configure
        config.timeout = 30
        config.retries = 3
        config.verbose = true
        config.debug = false
      end
    RUBY
  end

  test "registers offense for class methods" do
    assert_offense <<~RUBY
      def self.process
        user = find_user
        account = user.account
        plan = account.plan
        features = plan.features
      end
    RUBY
  end

  test "allows empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "counts variables in blocks" do
    assert_offense <<~RUBY
      def process
        a = 1
        b = 2
        items.each do |item|
          c = item.value
          d = c * 2
        end
      end
    RUBY
  end

  test "registers offense for method with too many local vars in nested class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def process
              user = find_user
              account = user.account
              plan = account.plan
              features = plan.features
            end
          end
      end
    RUBY
  end

  test "allows method with few local vars in nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def process
              user = find_user
              account = user.account
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
                def process
                  a = 1
                  b = 2
                  c = 3
                  d = 4
                end
              end
          end
      end
    RUBY
  end

  test "each nested class method is analyzed independently" do
    assert_offense <<~RUBY, count: 1
      class Outer
        def outer_method
          a = 1
          b = 2
          c = 3
          d = 4
        end

        private
          class Inner
            def inner_method
              x = 1
              y = 2
            end
          end
      end
    RUBY
  end

  test "does not charge a method for assignments in a nested method definition" do
    assert_no_offense <<~RUBY
      def process
        result = prepare

        def helper
          first = 1
          second = 2
          third = 3
        end

        result
      end
    RUBY
  end

  test "charges a method for assignments evaluated while nested lexical definitions open" do
    assert_offense <<~RUBY
      def process
        first = build
        second = build
        def (third = build).run; hidden = build; end
        class << (fourth = build); also_hidden = build; end
      end
    RUBY
  end

  test "does not charge a method for assignments inside a lambda" do
    assert_no_offense <<~RUBY
      def process
        operation = -> do
          first = 1
          second = 2
          third = 3
        end
        operation.call
      end
    RUBY
  end
end
