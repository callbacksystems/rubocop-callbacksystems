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
    assert_includes offenses.first.message, "Methods `create, validate, save` all take `email, name, phone`"
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

  test "reports a shared core carried whole by every method as a tight clump" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def method1(alpha, beta, gamma, extra1); end
          def method2(gamma, alpha, beta, extra2); end
          def method3(beta, gamma, alpha, extra3); end
      end
    RUBY
    assert_includes offenses.first.message, "all take `alpha, beta, gamma`"
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
    assert_includes offenses.first.message, "thread `address, email, name, phone` between them"
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
    assert_includes offenses.first.message, "thread `alpha, delta, gamma` between them"
  end

  test "reports each disjoint component separately" do
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

    assert_equal 2, offenses.count
    assert_includes offenses.first.message, "account, role, user"
    assert_includes offenses.last.message, "depth, height, width"
  end

  test "reports only the component that reaches far enough" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def a1(user, account, role); end
          def a2(user, account, role); end
          def a3(user, account, role); end
          def b1(width, height); end
          def b2(height, depth); end
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

  test "exempts a recursion subject indexed and passed as itself in one call" do
    assert_no_offense <<~RUBY
      class Walker
        private
          def walk(node, key)
            descend(node[key], node)
          end

          def descend(child, node); end
          def first(node); end
          def second(node); end
          def third(node); end
          def fourth(node); end
          def fifth(node); end
      end
    RUBY
  end

  test "exempts a recursion subject handed on at a different parameter position" do
    assert_no_offense <<~RUBY
      class Scan
        private
          def walk(node, parent)
            found << node if reference?(node, parent)
            children_of(node).each { walk(it, node) }
          end

          def reference?(node, parent)
            !node.nil? && !parent.nil?
          end
      end
    RUBY
  end

  test "still flags a threaded parameter that is not the recursion subject" do
    offenses = assert_offense <<~RUBY
      class Walker
        private
          def walk(node, context)
            descend(node.child, node)
          end

          def descend(child, context); end
          def first(context); end
          def second(context); end
          def third(context); end
          def fourth(context); end
          def fifth(context); end
          def sixth(context); end
      end
    RUBY
    assert_includes offenses.first.message, "`context`"
  end

  test "allows a pair combined by one method and received singly by the others" do
    assert_no_offense <<~RUBY
      class Order
        private
          def one(alpha, beta); end
          def two(alpha); end
          def three(beta); end
      end
    RUBY
  end

  test "allows two pairs bridged by a shared name with no method taking three" do
    assert_no_offense <<~RUBY
      class Order
        private
          def one(alpha, beta); end
          def two(beta, gamma); end
          def three(alpha); end
          def four(gamma); end
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
    assert_includes offenses.first.message, "Methods `method1, method2, method3, method4, method5, method6` all take `state`"
  end

  test "counts a threaded parameter even alongside other parameters" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def method1(state, a); end
          def method2(state, b); end
          def method3(state, c); end
          def method4(state, d); end
          def method5(state, e); end
          def method6(state, f); end
      end
    RUBY
    assert_includes offenses.first.message, "`state`"
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

  test "registers offense for a signature repeated by only two methods" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def validate(user, account); end
          def execute(user, account); end
      end
    RUBY
    assert_includes offenses.first.message, "Methods `validate, execute` all take `account, user`"
  end

  test "allows a shared core reaching only two methods that carry extras" do
    assert_no_offense <<~RUBY
      class Order
        private
          def method1(user, account, extra1); end
          def method2(user, account, extra2); end
      end
    RUBY
  end

  test "allows two methods sharing a single parameter" do
    assert_no_offense <<~RUBY
      class Order
        private
          def method1(alpha, beta); end
          def method2(alpha, gamma); end
      end
    RUBY
  end

  test "allows private methods with no parameters" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate; end
          def execute; end
          def notify; end
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

  test "ignores methods declared before the private modifier" do
    assert_no_offense <<~RUBY
      class Order
        def validate(user, account); end
        def execute(user, account); end
        def notify(user, account); end

        private
          def helper; end
      end
    RUBY
  end

  test "works with class << self blocks" do
    offenses = assert_offense <<~RUBY
      class Order
        class << self
          private
            def validate(user, account); end
            def execute(user, account); end
            def notify(user, account); end
        end
      end
    RUBY
    assert_includes offenses.first.message, "Methods `validate, execute, notify` all take `account, user`"
  end

  test "allows class << self with different parameters" do
    assert_no_offense <<~RUBY
      class Order
        class << self
          private
            def validate(user, account); end
            def execute(order, items); end
            def notify(message, recipient); end
        end
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

  test "outer class public methods do not affect nested class analysis" do
    offenses = assert_offense <<~RUBY
      class Outer
        def public1(user, account); end
        def public2(user, account); end
        def public3(user, account); end

        private
          class Inner
            private
              def validate(x, y); end
              def execute(x, y); end
              def notify(x, y); end
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "x, y"
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
    offenses = assert_offense <<~RUBY
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
    assert_includes offenses.first.message, "Methods `method1, method2, method3`"
  end
end
