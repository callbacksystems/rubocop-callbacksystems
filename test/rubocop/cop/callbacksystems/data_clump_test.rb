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
    assert_includes offenses.first.message, "email, name, phone"
    assert_includes offenses.first.message, "3 private methods (`create, validate, save`)"
  end

  test "registers offense when private methods share parameters called from a public method" do
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

  test "allows a single private method" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user, account); end
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

  test "registers offense for a signature repeated verbatim in two private methods" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def create(name, email, phone); end
          def validate(name, email, phone); end
      end
    RUBY
    assert_includes offenses.first.message, "email, name, phone"
    assert_includes offenses.first.message, "2 private methods (`create, validate`)"
  end

  test "registers one clump for a wide repeated signature" do
    parameters = 1_000.times.map { "parameter_#{it}" }.join(", ")

    assert_offense <<~RUBY, count: 1
      class WideContext
        private
          def first(#{parameters}); end
          def second(#{parameters}); end
      end
    RUBY
  end

  test "reads a signature repeated in another order as the same signature" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def validate(user, account); end
          def execute(account, user); end
      end
    RUBY
    assert_includes offenses.first.message, "account, user"
  end

  test "allows two methods sharing a core with extras of their own" do
    assert_no_offense <<~RUBY
      class Order
        private
          def create(name, email, phone); end
          def validate(name, email, address); end
      end
    RUBY
  end

  test "allows two methods where one signature is a subset of the other" do
    assert_no_offense <<~RUBY
      class Order
        private
          def method1(alpha, beta); end
          def method2(alpha, beta, gamma); end
      end
    RUBY
  end

  test "detects the shared parameter core when each method adds an extra" do
    offenses = assert_offense <<~RUBY
      class Order
        private
          def method1(alpha, beta, gamma, extra1); end
          def method2(alpha, beta, gamma, extra2); end
          def method3(alpha, beta, gamma, extra3); end
      end
    RUBY
    assert_includes offenses.first.message, "alpha, beta, gamma"
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
    assert_includes offenses.first.message, "travel together through 3 private methods"
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
    assert_includes offenses.first.message, "alpha, delta, gamma"
    assert_includes offenses.first.message, "travel together through 3 private methods"
  end

  test "counts every method carrying two names of the set" do
    offenses = assert_offense <<~RUBY
      class Pipeline
        private
          def one(alpha, beta); end
          def two(alpha, beta, gamma); end
          def three(beta, alpha); end
          def four(alpha, gamma); end
      end
    RUBY
    assert_includes offenses.first.message, "alpha, beta, gamma"
    assert_includes offenses.first.message, "4 private methods (`one, two, three, four`)"
  end

  test "does not count a method carrying one name of the set" do
    assert_no_offense <<~RUBY
      class Pipeline
        private
          def one(alpha, beta); end
          def two(alpha); end
          def three(beta); end
      end
    RUBY
  end

  test "does not let bystanders carry a set past the method threshold" do
    assert_no_offense <<~RUBY
      class Pipeline
        private
          def one(alpha, beta); end
          def two(beta, gamma); end
          def three(alpha); end
          def four(gamma); end
      end
    RUBY
  end

  test "reports each component as its own clump" do
    offenses = assert_offense <<~RUBY, count: 2
      class Order
        private
          def a1(user, account, role); end
          def a2(user, account, role); end
          def a3(user, account, role); end
          def b1(width, height, depth); end
          def b2(width, height, depth); end
      end
    RUBY
    assert_includes offenses.first.message, "account, role, user"
    assert_includes offenses.last.message, "depth, height, width"
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

  test "exempts a threaded recursion subject passed both directly and as a derivative" do
    assert_no_offense <<~RUBY
      class Walker
        private
          def walk(node)
            descend(node.child, node)
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
    assert_includes offenses.first.message, "Parameter `context` is threaded"
  end

  test "does not borrow a recursion exemption from a nested class" do
    offenses = assert_offense <<~RUBY
      class Pipeline
        private
          def first(node); end
          def second(node); end
          def third(node); end
          def fourth(node); end
          def fifth(node); end
          def sixth(node); end

          class Walker
            def walk(node)
              descend(node.child, node)
            end
          end
      end
    RUBY

    assert_includes offenses.first.message, "Parameter `node` is threaded"
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

  test "allows three private methods sharing only one parameter" do
    assert_no_offense <<~RUBY
      class Order
        private
          def validate(user); end
          def execute(user); end
          def notify(user); end
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
    assert_includes offenses.first.message, "Parameter `state` is threaded through 6 private methods"
    assert_includes offenses.first.message, "method1, method2, method3, method4, method5, method6"
  end

  test "counts a threaded parameter even alongside other parameters" do
    offenses = assert_offense <<~RUBY
      class Visitor
        private
          def first(node, alpha); end
          def second(node, beta); end
          def third(node, gamma); end
          def fourth(node, delta); end
          def fifth(node, epsilon); end
          def sixth(node, zeta); end
      end
    RUBY
    assert_includes offenses.first.message, "Parameter `node` is threaded"
  end

  test "allows a single parameter threaded through many public methods" do
    assert_no_offense <<~RUBY
      class Visitor
        def first(node); end
        def second(node); end
        def third(node); end
        def fourth(node); end
        def fifth(node); end
        def sixth(node); end
        def seventh(node); end
      end
    RUBY
  end

  test "works with modules" do
    offenses = assert_offense <<~RUBY
      module Processable
        private
          def process(host, port, path); end
          def validate(host, port, path); end
          def store(host, port, path); end
      end
    RUBY
    assert_includes offenses.first.message, "process, validate, store"
  end

  test "works with class << self blocks" do
    offenses = assert_offense <<~RUBY, count: 1
      class Order
        class << self
          private
            def validate(user, account); end
            def execute(user, account); end
            def notify(user, account); end
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
            def validate(user, account); end
            def execute(order, items); end
            def notify(message, recipient); end
        end
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

  test "ignores methods before the private declaration" do
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

  test "registers offense for data clump in private nested class" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def method1(alpha, beta, gamma); end
            def method2(alpha, beta, gamma); end
            def method3(alpha, beta, gamma); end
          end
      end
    RUBY
  end

  test "registers offense for data clump in the private section of a private nested class" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          class Inner
            private
              def validate(user, account); end
              def execute(user, account); end
              def notify(user, account); end
          end
      end
    RUBY
    assert_includes offenses.first.message, "validate, execute, notify"
  end

  test "nested class clumps are analyzed independently from outer class" do
    assert_offense <<~RUBY, count: 2
      class Outer
        private
          def outer1(host, port, path); end
          def outer2(host, port, path); end
          def outer3(host, port, path); end

          class Inner
            def inner1(alpha, beta, gamma); end
            def inner2(alpha, beta, gamma); end
            def inner3(alpha, beta, gamma); end
          end
      end
    RUBY
  end

  test "outer class public methods do not affect nested class analysis" do
    offenses = assert_offense <<~RUBY, count: 1
      class Outer
        def public1(user, account); end
        def public2(user, account); end
        def public3(user, account); end

        private
          class Inner
            private
              def validate(host, port); end
              def execute(host, port); end
              def notify(host, port); end
          end
      end
    RUBY

    assert_includes offenses.first.message, "host, port"
  end

  test "allows nested class with no data clump" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def method1(alpha, beta, gamma); end
            def method2(delta, epsilon, zeta); end
            def method3(eta, theta, iota); end
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
    assert_includes offenses.first.message, "method1, method2, method3"
  end

  test "single-parameter detection works inside a private nested class" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          class Inner
            private
              def first(node); end
              def second(node); end
              def third(node); end
              def fourth(node); end
              def fifth(node); end
              def sixth(node); end
          end
      end
    RUBY
    assert_includes offenses.first.message, "Parameter `node` is threaded"
  end
end
