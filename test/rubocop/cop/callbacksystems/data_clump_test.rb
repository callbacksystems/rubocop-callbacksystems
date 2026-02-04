require "test_helper"

class RuboCop::Cop::Callbacksystems::DataClumpTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::DataClump

  test "registers offense for same params in multiple methods" do
    offenses = assert_offense <<~RUBY
      class Order
        def create(name, email, phone)
          validate(name, email, phone)
        end

        def validate(name, email, phone); end
        def save(name, email, phone); end
      end
    RUBY
    assert_match(/email.*name.*phone|email.*phone.*name|name.*email.*phone|name.*phone.*email|phone.*email.*name|phone.*name.*email/, offenses.first.message)
  end

  test "allows methods with different params" do
    assert_no_offense <<~RUBY
      class Order
        def create(name, email)
          validate(phone, address)
        end

        def validate(phone, address); end
        def save(id, timestamp); end
      end
    RUBY
  end

  test "allows methods with fewer common params" do
    assert_no_offense <<~RUBY
      class Order
        def create(name, email, other1)
          validate(name, email, other2)
        end

        def validate(name, email, other2); end
        def save(name, email, other3); end
      end
    RUBY
  end

  test "allows fewer methods with same params" do
    assert_no_offense <<~RUBY
      class Order
        def create(name, email, phone); end
        def validate(name, email, phone); end
      end
    RUBY
  end

  test "detects partial overlap with minimum params" do
    offenses = assert_offense <<~RUBY
      class Order
        def method1(a, b, c, extra1); end
        def method2(a, b, c, extra2); end
        def method3(a, b, c, extra3); end
      end
    RUBY
    assert_includes offenses.first.message, "a, b, c"
  end

  test "works with modules" do
    assert_offense <<~RUBY
      module Processable
        def process(x, y, z); end
        def validate(x, y, z); end
        def store(x, y, z); end
      end
    RUBY
  end

  test "ignores methods with too few params" do
    assert_no_offense <<~RUBY
      class Order
        def method1(a, b); end
        def method2(a, b); end
        def method3(a, b); end
      end
    RUBY
  end

  test "registers offense for data clump in private nested class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def method1(a, b, c); end
            def method2(a, b, c); end
            def method3(a, b, c); end
          end
      end
    RUBY
  end

  test "nested class clumps are analyzed independently from outer class" do
    offenses = assert_offense <<~RUBY
      class Outer
        def outer1(x, y, z); end
        def outer2(x, y, z); end
        def outer3(x, y, z); end

        private
          class Inner
            def inner1(a, b, c); end
            def inner2(a, b, c); end
            def inner3(a, b, c); end
          end
      end
    RUBY

    # Should have offenses for both outer (x,y,z) and inner (a,b,c)
    assert_equal 2, offenses.count
  end

  test "allows nested class with no data clump" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def method1(a, b, c); end
            def method2(d, e, f); end
            def method3(g, h, i); end
          end
      end
    RUBY
  end

  test "detects data clump in deeply nested private class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Middle
            private
              class Inner
                def method1(user, account, permissions); end
                def method2(user, account, permissions); end
                def method3(user, account, permissions); end
              end
          end
      end
    RUBY
  end
end
