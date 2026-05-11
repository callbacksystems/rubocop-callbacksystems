require "test_helper"

class PreferAttrReaderOverInstanceVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferAttrReaderOverInstanceVariable

  test "registers offense for direct ivar usage when assigned in initialize" do
    offenses = assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end

        def process
          @node.children
        end
      end
    RUBY

    assert_equal 1, offenses.count
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

  test "no offense for ivar not assigned in initialize" do
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

  test "no offense when class has no initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          @node.children
        end
      end
    RUBY
  end

  test "registers offense for direct ivar usage in private nested class" do
    offenses = assert_offense <<~RUBY
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

    assert_equal 1, offenses.count
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

  test "registers offense for all direct ivar usages in nested class" do
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

    # Should flag ALL direct ivar usages: @object, @default, @card_id, and @pay_customer
    # Even though pay_customer has attr_reader, using @pay_customer directly is still wrong
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

    # Should flag @outer_var and @inner_one_var but NOT @inner_two_var
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
end
