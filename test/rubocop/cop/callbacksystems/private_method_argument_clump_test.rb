require "test_helper"

class RuboCop::Cop::Callbacksystems::PrivateMethodArgumentClumpTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateMethodArgumentClump

  test "registers offense when 3+ private methods share 2+ parameters" do
    offenses = assert_offense <<~RUBY
      class Order
        def process
          validate(user, account)
          execute(user, account)
          notify(user, account)
        end

        private
          def validate(user, account)
            # ...
          end

          def execute(user, account)
            # ...
          end

          def notify(user, account)
            # ...
          end
      end
    RUBY
    assert_includes offenses.first.message, "validate, execute, notify"
    assert_includes offenses.first.message, "account, user"
  end

  test "allows 2 private methods sharing same parameters" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user, account)
            # ...
          end

          def execute(user, account)
            # ...
          end
      end
    RUBY
  end

  test "allows 3 private methods sharing only 1 parameter" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user)
            # ...
          end

          def execute(user)
            # ...
          end

          def notify(user)
            # ...
          end
      end
    RUBY
  end

  test "allows private methods with different parameters" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user, account)
            # ...
          end

          def execute(order, items)
            # ...
          end

          def notify(message, recipient)
            # ...
          end
      end
    RUBY
  end

  test "allows public methods with same parameters" do
    assert_no_offense <<~RUBY
      class Order
        def validate(user, account)
          # ...
        end

        def execute(user, account)
          # ...
        end

        def notify(user, account)
          # ...
        end
      end
    RUBY
  end

  test "allows single private method" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user, account)
            # ...
          end
      end
    RUBY
  end

  test "allows private methods with no parameters" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate
            # ...
          end

          def execute
            # ...
          end

          def notify
            # ...
          end
      end
    RUBY
  end

  test "works with modules" do
    offenses = assert_offense <<~RUBY
      module Processable
        private
          def validate(user, account)
            # ...
          end

          def execute(user, account)
            # ...
          end

          def notify(user, account)
            # ...
          end
      end
    RUBY
    assert_includes offenses.first.message, "validate, execute, notify"
  end

  test "ignores methods before private declaration" do
    assert_no_offense <<~RUBY
      class Order
        def validate(user, account)
          # ...
        end

        def execute(user, account)
          # ...
        end

        def notify(user, account)
          # ...
        end

        private
          def helper
            # ...
          end
      end
    RUBY
  end

  test "works with class << self blocks" do
    offenses = assert_offense <<~RUBY
      class Order
        class << self
          private
            def validate(user, account)
              # ...
            end

            def execute(user, account)
              # ...
            end

            def notify(user, account)
              # ...
            end
        end
      end
    RUBY
    assert_includes offenses.first.message, "validate, execute, notify"
  end

  test "allows class << self with different parameters" do
    assert_no_offense <<~RUBY
      class Order
        class << self
          private
            def validate(user, account)
              # ...
            end

            def execute(order, items)
              # ...
            end

            def notify(message, recipient)
              # ...
            end
        end
      end
    RUBY
  end

  test "registers offense for argument clump in private nested class" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          class Inner
            private
              def validate(user, account)
                # ...
              end

              def execute(user, account)
                # ...
              end

              def notify(user, account)
                # ...
              end
          end
      end
    RUBY
    assert_includes offenses.first.message, "validate, execute, notify"
  end

  test "nested class clumps are analyzed independently from outer class" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          def outer1(x, y)
            # ...
          end

          def outer2(x, y)
            # ...
          end

          def outer3(x, y)
            # ...
          end

          class Inner
            private
              def inner1(a, b)
                # ...
              end

              def inner2(a, b)
                # ...
              end

              def inner3(a, b)
                # ...
              end
          end
      end
    RUBY

    # Should have offenses for both outer (x,y) and inner (a,b)
    assert_equal 2, offenses.count
  end

  test "allows private nested class with no argument clump" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            private
              def validate(user, account)
                # ...
              end

              def execute(order, items)
                # ...
              end

              def notify(message, recipient)
                # ...
              end
          end
      end
    RUBY
  end

  test "detects argument clump in deeply nested private class" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          class Middle
            private
              class Inner
                private
                  def method1(user, account)
                    # ...
                  end

                  def method2(user, account)
                    # ...
                  end

                  def method3(user, account)
                    # ...
                  end
              end
          end
      end
    RUBY
    assert_includes offenses.first.message, "method1, method2, method3"
  end

  test "outer class public methods don't affect nested class analysis" do
    offenses = assert_offense <<~RUBY
      class Outer
        def public1(user, account); end
        def public2(user, account); end
        def public3(user, account); end

        private
          class Inner
            private
              def validate(x, y)
                # ...
              end

              def execute(x, y)
                # ...
              end

              def notify(x, y)
                # ...
              end
          end
      end
    RUBY

    # Should only flag Inner's private methods, not Outer's public methods
    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "x, y"
  end
end
