require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDelegateOverIvarAssignmentTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDelegateOverIvarAssignment

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
    offenses = assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
          @body = node.body
          @loc = node.loc
        end
      end
    RUBY

    assert_equal 2, offenses.size
  end

  test "does not flag when ivar name differs from method name" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(name)
          @name = name
          @name_parts = name.split("_")
        end
      end
    RUBY
  end

  test "does not flag when the receiver is not assigned to a matching ivar" do
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

  test "does not flag ivar assignments outside of initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def setup(node)
          @node = node
          @body = node.body
        end
      end
    RUBY
  end

  test "does not flag a plain `@x = x` ivar assignment" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end
      end
    RUBY
  end

  test "does not flag when the receiver is an ivar instead of an lvar" do
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

  test "does not flag when there is only one statement in initialize" do
    assert_no_offense <<~RUBY
      class Foo
        def initialize(node)
          @body = node.body
        end
      end
    RUBY
  end
end
