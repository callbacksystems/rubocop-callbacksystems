require "test_helper"

class PreferAttrReaderOverInstanceVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferAttrReaderOverInstanceVariable

  test "registers offense for direct instance variable usage when assigned in initialize" do
    offenses = assert_offense <<~RUBY, count: 1
      class Foo
        def initialize(node)
          @node = node
        end

        def process
          @node.children
        end
      end
    RUBY

    assert_includes offenses.first.message, "node"
  end

  test "no offense when using attr_reader" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end

        def process
          node.children
        end

        private
          attr_reader :node
      end
    RUBY
  end

  test "no offense for an instance variable not assigned in initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def setup
          @node = find_node
        end

        def process
          @node.children
        end
      end
    RUBY
  end

  test "no offense inside initialize itself" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @processed = @node.process
        end
      end
    RUBY
  end

  test "no offense for a class-level instance variable read" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end

        @node.children
      end
    RUBY
  end

  test "no offense when class has no initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          @node.children
        end
      end
    RUBY
  end

  test "registers offense for direct instance variable usage in private nested class" do
    offenses = assert_offense <<~RUBY, count: 1
      class Outer
        private
          class Inner
            def initialize(node)
              @node = node
            end

            def process
              @node.children
            end
          end
      end
    RUBY

    assert_includes offenses.first.message, "node"
  end

  test "no offense when nested class uses attr_reader" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def initialize(node)
              @node = node
            end

            def process
              node.children
            end

            private
              attr_reader :node
          end
      end
    RUBY
  end

  test "registers offense for direct instance variable usage in nested class even when an attr_reader exists" do
    offenses = assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def initialize(card_id, object, pay_customer, default)
              @card_id = card_id
              @object = object
              @pay_customer = pay_customer
              @default = default
            end

            def sync
              sync_payment_method if @object
            end

            def clear_defaults
              @pay_customer.payment_methods.where.not(id: @default).update_all(default: false)
            end

            private
              attr_reader :pay_customer

              def retrieve
                @object ||= retrieve_card(@card_id, @pay_customer)
              end
          end
      end
    RUBY
    ivar_names = offenses.map { it.message[/`(\w+)`/, 1] }

    assert_includes ivar_names, "object"
    assert_includes ivar_names, "default"
    assert_includes ivar_names, "card_id"
    assert_includes ivar_names, "pay_customer"
  end

  test "each nested class is analyzed independently" do
    offenses = assert_offense <<~RUBY
      class Outer
        def initialize(outer_var)
          @outer_var = outer_var
        end

        def outer_method
          @outer_var.call
        end

        private
          class InnerOne
            def initialize(inner_one_var)
              @inner_one_var = inner_one_var
            end

            def process
              @inner_one_var.run
            end
          end

          class InnerTwo
            def initialize(inner_two_var)
              @inner_two_var = inner_two_var
            end

            def execute
              inner_two_var.run
            end

            private
              attr_reader :inner_two_var
          end
      end
    RUBY

    ivar_names = offenses.map { it.message[/`(\w+)`/, 1] }

    assert_includes ivar_names, "outer_var"
    assert_includes ivar_names, "inner_one_var"
    assert_not_includes ivar_names, "inner_two_var"
  end

  test "ignores initialize defined inside a nested module" do
    assert_no_offense <<~RUBY
      class Outer
        module Inner
          def initialize(node)
            @node = node
          end
        end

        def process
          @node.foo
        end
      end
    RUBY
  end

  test "does not flag ivars used inside a nested module" do
    assert_no_offense <<~RUBY
      class Outer
        def initialize(value)
          @value = value
        end

        module Helper
          def use
            @value
          end
        end
      end
    RUBY
  end

  test "does not attribute an anonymous class reader to the outer class" do
    assert_no_offense <<~RUBY
      class Report
        def initialize(value)
          @value = value
        end

        Handler = Class.new do
          def render
            @value
          end
        end
      end
    RUBY
  end

  test "does not attribute constructor state in class and module builders to the outer instance" do
    assert_no_offense <<~RUBY
      class Report
        def initialize
          Class.new { @class_value = build }
          Module.new { @module_value = build }
        end

        def render
          [ @class_value, @module_value ]
        end
      end
    RUBY
  end

  test "does not attribute reads in class and module builders to the outer instance" do
    assert_no_offense <<~RUBY
      class Report
        def initialize(value)
          @value = value
        end

        def handlers
          [ Class.new { @value }, Module.new { @value } ]
        end
      end
    RUBY
  end

  test "keeps reads in ordinary and deferred blocks on the outer instance" do
    assert_offense <<~RUBY, count: 2
      class Report
        def initialize(value)
          @value = value
        end

        def handlers
          items.each { use(@value) }
          -> { use(@value) }
        end
      end
    RUBY
  end

  test "keeps a builder argument assignment on the outer instance" do
    assert_offense <<~RUBY
      class Report
        def initialize(value)
          Class.new(@value = value) {}
        end

        def render
          @value
        end
      end
    RUBY
  end

  test "separates evaluation against another receiver from evaluation against self" do
    assert_offense <<~RUBY, count: 1
      class Report
        def initialize(value)
          @value = value
        end

        def render(target)
          target.instance_eval { use(@value) }
          self.instance_eval { use(@value) }
        end
      end
    RUBY
  end

  test "does not attribute constructor state evaluated against another receiver" do
    assert_no_offense <<~RUBY
      class Report
        def initialize(target)
          target.instance_exec { @value = build }
        end

        def render
          @value
        end
      end
    RUBY
  end

  test "does not mix an instance variable with state on the class object" do
    assert_no_offense <<~RUBY
      class Report
        @format = :json

        def initialize(format)
          @format = format
        end

        def self.format
          @format
        end
      end
    RUBY
  end

  test "allows a class with no body" do
    assert_no_offense <<~RUBY
      class Report
      end
    RUBY
  end
end
