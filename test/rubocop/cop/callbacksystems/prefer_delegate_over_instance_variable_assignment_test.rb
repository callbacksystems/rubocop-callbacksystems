require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDelegateOverInstanceVariableAssignmentTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDelegateOverInstanceVariableAssignment

  test "flags @x = receiver.x when receiver is also assigned to @receiver in initialize" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end
      end
    RUBY
  end

  test "flags multiple mirroring assignments in the same initialize" do
    assert_offense <<~RUBY, count: 2
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
          @loc = node.loc
        end
      end
    RUBY
  end

  test "does not flag when the variable name differs from the method name" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(name)
          @name = name
          @name_parts = name.split("_")
        end
      end
    RUBY
  end

  test "does not flag when the receiver is not assigned to a matching variable" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag when the receiver call has arguments" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(formatter)
          @formatter = formatter
          @output = formatter.output(:default)
        end
      end
    RUBY
  end

  test "does not flag instance variable assignments outside of initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def setup(node)
          @node = node
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag a plain `@x = x` assignment" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end
      end
    RUBY
  end

  test "does not flag when the receiver is an instance variable instead of a local" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = @node.body
        end
      end
    RUBY
  end

  test "flags assignment even when other statements are present in initialize" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node, extra)
          validate(extra)
          @node = node
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag when the receiver local is rebound after the instance variable captures it" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          node = decorate(node)
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag when a pattern binding rebinds the receiver local" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node, replacement)
          @node = node
          replacement => node
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag conditional receiver or mirrored assignments" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node if retain_node?
          @body = node.body
        end
      end

      class Bar
        def initialize(node)
          @node = node
          @body = node.body if cache_body?
        end
      end
    RUBY
  end

  test "does not flag a mirrored assignment nested in another statement" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          configure { @body = node.body }
        end
      end
    RUBY
  end

  test "does not flag when the receiver assignment follows the mirrored value" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @body = node.body
          @node = node
        end
      end
    RUBY
  end

  test "does not flag instance state overwritten after the mirrored assignment" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
          @node = fallback_node
        end
      end

      class Bar
        def initialize(node)
          @node = node
          @body = node.body
          @body = normalized_body
        end
      end
    RUBY
  end

  test "does not flag a receiver that another method can overwrite" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end

        def replace_node(node)
          @node = node
        end
      end
    RUBY
  end

  test "ignores same-named state in a class builder nested in initialize" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          Class.new do
            @node = fallback
            @body = fallback.body
          end
          @body = node.body
        end
      end
    RUBY
  end

  test "ignores same-named state on the class object" do
    assert_offense <<~RUBY
      class Foo
        @node = default_node
        @body = @node.body

        def initialize(node)
          @node = node
          @body = node.body
        end
      end
    RUBY
  end

  test "keeps same-named state captured by a lambda on the outer instance" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end

        def replace_later
          -> { @body = replacement }
        end
      end
    RUBY
  end

  test "ignores same-named state evaluated against another receiver" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end

        def configure(target)
          target.instance_eval { @body = replacement }
        end
      end
    RUBY
  end

  test "keeps same-named state evaluated against the current self" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end

        def configure
          self.instance_eval { @body = replacement }
        end
      end
    RUBY
  end

  test "ignores same-named writes belonging to a nested class" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
        end

        class Nested
          def initialize(node)
            @node = node
          end
        end
      end
    RUBY
  end

  test "analyzes an anonymous class in its own instance domain" do
    assert_offense <<~RUBY
      class Foo
        Handler = Class.new do
          def initialize(node)
            @node = node
            @body = node.body
          end
        end
      end
    RUBY
  end

  test "does not flag when there is only one statement in initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag instance state outside a class or module" do
    assert_no_offense <<~RUBY
      def initialize(node)
        @node = node
        @body = node.body
      end
    RUBY
  end
end
