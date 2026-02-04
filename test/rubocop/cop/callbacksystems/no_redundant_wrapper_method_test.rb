require "test_helper"

class NoRedundantWrapperMethodTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoRedundantWrapperMethod

  test "registers offense for private method that only wraps another method" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def find_all
            find(@node)
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "find_all"
  end

  test "registers offense for private method passing through arguments" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def process(node)
            analyze(node)
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "allows public method that wraps" do
    assert_no_offense <<~RUBY
      class Foo
        def authenticated?
          resume_session
        end
      end
    RUBY
  end

  test "allows predicate method that wraps" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def fulfillable?
            paid?
          end
      end
    RUBY
  end

  test "no offense when method chains result" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def find_all
            find(@node).compact
          end
      end
    RUBY
  end

  test "no offense when method transforms arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def process(node)
            analyze(node.children.first)
          end
      end
    RUBY
  end

  test "no offense when method adds arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def process(node)
            analyze(node, default_config)
          end
      end
    RUBY
  end

  test "no offense when method has conditional" do
    assert_no_offense <<~RUBY
      def process(node)
        analyze(node) if node
      end
    RUBY
  end

  test "no offense for empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "registers offense for private method calling with subset of params" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def process(node, config)
            analyze(node)
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
