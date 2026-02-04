require "test_helper"

class RuboCop::Cop::Callbacksystems::InlineMemoizedComputationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::InlineMemoizedComputation

  test "registers offense when memoizing call to own method without arguments" do
    assert_offense <<~RUBY
      class Foo
        def user
          @user ||= find_user
        end

        private
          def find_user
            User.find(1)
          end
      end
    RUBY
  end

  test "registers offense when memoizing call to own public method" do
    assert_offense <<~RUBY
      class Foo
        def cached_value
          @cached_value ||= compute_value
        end

        def compute_value
          expensive_operation
        end
      end
    RUBY
  end

  test "allows memoizing call with receiver" do
    assert_no_offense <<~RUBY
      class Foo
        def user
          @user ||= User.find(params[:id])
        end
      end
    RUBY
  end

  test "allows memoizing call with arguments" do
    assert_no_offense <<~RUBY
      class Foo
        def formatted_name
          @formatted_name ||= format_name(first, last)
        end

        private
          def format_name(first, last)
            "\#{first} \#{last}"
          end
      end
    RUBY
  end

  test "allows memoization with additional logic" do
    assert_no_offense <<~RUBY
      class Foo
        def user
          @user ||= find_user || default_user
        end

        private
          def find_user
            User.find_by(id: 1)
          end

          def default_user
            User.new
          end
      end
    RUBY
  end

  test "allows memoization in module" do
    assert_no_offense <<~RUBY
      module Foo
        def user
          @user ||= User.find(1)
        end
      end
    RUBY
  end

  test "allows when method does not exist in class" do
    assert_no_offense <<~RUBY
      class Foo
        def user
          @user ||= external_helper
        end
      end
    RUBY
  end

  test "allows non-memoization methods" do
    assert_no_offense <<~RUBY
      class Foo
        def user
          find_user
        end

        private
          def find_user
            User.find(1)
          end
      end
    RUBY
  end

  test "allows memoization with begin block" do
    assert_no_offense <<~RUBY
      class Foo
        def user
          @user ||= begin
            data = fetch_data
            process(data)
          end
        end
      end
    RUBY
  end

  test "does not flag memoization when method only exists in nested class" do
    assert_no_offense <<~RUBY
      class Outer
        def user
          @user ||= find_user
        end

        private
          class Inner
            def find_user
              User.find(1)
            end
          end
      end
    RUBY
  end

  test "does not consider methods from nested classes as own methods" do
    assert_no_offense <<~RUBY
      class Outer
        def cached
          @cached ||= compute
        end

        private
          class Helper
            def compute
              expensive_operation
            end
          end
      end
    RUBY
  end

  test "still flags when method exists in same class, not nested class" do
    assert_offense <<~RUBY
      class Outer
        def user
          @user ||= find_user
        end

        private
          def find_user
            User.find(1)
          end

          class Inner
            def other_method
            end
          end
      end
    RUBY
  end

  test "flags method in nested class calling its own method" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def user
              @user ||= find_user
            end

            private
              def find_user
                User.find(1)
              end
          end
      end
    RUBY
  end
end
