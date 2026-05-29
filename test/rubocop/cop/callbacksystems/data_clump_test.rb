require "test_helper"

class RuboCop::Cop::Callbacksystems::DataClumpTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::DataClump

  test "registers offense for same params in multiple private methods" do
    offenses = assert_offense <<~RUBY
      class Order
        private
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
        private
          def create(name, email)
            validate(phone, address)
          end

          def validate(phone, address); end
          def save(id, timestamp); end
      end
    RUBY
  end

  test "registers offense for two params shared across three methods" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def create(name, email, other1)
            validate(name, email, other2)
          end

          def validate(name, email, other2); end
          def save(name, email, other3); end
      end
    RUBY
    assert_includes offenses.first.message, "email, name"
  end

  test "allows a clump reaching only two methods (below the method threshold)" do
    assert_no_offense <<~RUBY
      class Order
        private
          def create(name, email, phone); end
          def validate(name, email, phone); end
      end
    RUBY
  end

  test "detects the shared parameter core when each method adds an extra" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def method1(a, b, c, extra1); end
          def method2(a, b, c, extra2); end
          def method3(a, b, c, extra3); end
      end
    RUBY
    assert_includes offenses.first.message, "a, b, c"
  end

  test "detects names traveling together in varying combinations with no repeated pair" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def create(name, email, phone); end
          def validate(name, email, address); end
          def save(name, phone, address); end
      end
    RUBY
    assert_includes offenses.first.message, "address, email, name, phone"
    assert_includes offenses.first.message, "appear together in 3 methods"
  end

  test "links names into one component through a connecting parameter" do
    offenses = assert_offense <<~RUBY
      class Pipeline
        private
          def first(alpha, gamma, one); end
          def second(gamma, delta, two); end
          def third(alpha, delta, three); end
      end
    RUBY
    # alpha, gamma and delta are each shared by two methods and co-occur pairwise,
    # forming one component reaching all three methods; the unshared one/two/three
    # are not part of it.
    assert_includes offenses.first.message, "alpha, delta, gamma"
    assert_includes offenses.first.message, "appear together in 3 methods"
  end

  test "reports the component reaching the most methods when several exist" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def a1(user, account, role); end
          def a2(user, account, role); end
          def a3(user, account, role); end
          def b1(width, height, depth); end
          def b2(width, height, depth); end
      end
    RUBY
    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "account, role, user"
  end

  test "exempts the recursion subject passed both directly and as a derived value" do
    assert_no_offense <<~RUBY
      class Walker
        private
          def walk(node, scope)
            walk(node.child, node)
          end

          def visit(node, scope); end
          def leave(node, scope); end
      end
    RUBY
  end

  test "allows a single shared parameter below the single-parameter threshold" do
    assert_no_offense <<~RUBY
      class Order
        private
          def method1(only); end
          def method2(only); end
          def method3(only); end
          def method4(only); end
          def method5(only); end
      end
    RUBY
  end

  test "registers offense for a single parameter threaded through enough methods" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def method1(state); end
          def method2(state); end
          def method3(state); end
          def method4(state); end
          def method5(state); end
          def method6(state); end
      end
    RUBY
    assert_includes offenses.first.message, "state"
    assert_includes offenses.first.message, "appear together in 6 methods"
  end

  test "works with modules" do
    assert_offense <<~RUBY
      module Processable
        private
          def process(x, y, z); end
          def validate(x, y, z); end
          def store(x, y, z); end
      end
    RUBY
  end

  test "allows a two-name clump reaching only two methods" do
    assert_no_offense <<~RUBY
      class Order
        private
          def method1(alpha, beta); end
          def method2(alpha, beta); end
      end
    RUBY
  end

  test "exempts public methods because their signature answers to an interface" do
    assert_no_offense <<~RUBY
      class Order
        def create(name, email, phone); end
        def validate(name, email, phone); end
        def save(name, email, phone); end
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
        private
          def outer1(x, y, z); end
          def outer2(x, y, z); end
          def outer3(x, y, z); end

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
