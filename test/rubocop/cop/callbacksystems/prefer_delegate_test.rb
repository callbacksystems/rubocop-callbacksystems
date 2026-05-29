require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDelegateTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDelegate

  test "registers offense for a private method delegating to a same-named method" do
    assert_offense <<~RUBY
      class Foo
        private
          def size
            node.size
          end
      end
    RUBY
  end

  test "registers offense for a private predicate delegation" do
    assert_offense <<~RUBY
      class Foo
        private
          def operator_method?
            node.operator_method?
          end
      end
    RUBY
  end

  test "allows public delegations (handled by Rails/Delegate)" do
    assert_no_offense <<~RUBY
      class Foo
        def size
          node.size
        end
      end
    RUBY
  end

  test "allows a method that transforms instead of delegating purely" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def count
            node.size
          end
      end
    RUBY
  end

  test "allows a method that passes arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def fetch(key)
            node.fetch(key)
          end
      end
    RUBY
  end

  test "allows delegation whose receiver takes arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def size
            node(scope).size
          end
      end
    RUBY
  end

  test "allows delegation to an instance variable" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def size
            @node.size
          end
      end
    RUBY
  end

  test "autocorrects a lone private delegation to the macro" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "folds into an existing same-receiver delegate" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            attr_reader :node
            delegate :name, to: :node, private: true

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            attr_reader :node
            delegate :name, :size, to: :node, private: true
        end
      RUBY
  end

  test "writes a new delegate beside existing declarations" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            attr_reader :node

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            attr_reader :node
            delegate :size, to: :node, private: true
        end
      RUBY
  end
end
