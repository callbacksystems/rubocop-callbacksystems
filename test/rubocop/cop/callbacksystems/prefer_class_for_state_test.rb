require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferClassForStateTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferClassForState

  test "registers offense for a parameter threaded through four methods" do
    offenses = assert_offense <<~RUBY
      def rewrite(node)
        validate(node)
        decorate(node)
        persist(node)
        index(node)
      end
    RUBY
    assert_includes offenses.first.message, "`node` is threaded through 4 methods"
  end

  test "registers offense for a local threaded through four methods" do
    offenses = assert_offense <<~RUBY
      def run(input)
        model = build(input)
        a(model)
        b(model)
        c(model)
        d(model)
      end
    RUBY
    assert_includes offenses.first.message, "`model`"
  end

  test "allows a value passed to fewer than the threshold" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        validate(node)
        decorate(node)
      end
    RUBY
  end

  test "ignores a value used only as a receiver" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        node.validate
        node.decorate
        node.persist
        node.index
      end
    RUBY
  end

  test "ignores members of the value rather than the value itself" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        validate(node.left)
        decorate(node.right)
        persist(node.parent)
        index(node.children)
      end
    RUBY
  end

  test "ignores values passed to methods that have a receiver" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        first.validate(node)
        second.decorate(node)
        third.persist(node)
        fourth.index(node)
      end
    RUBY
  end

  test "counts distinct methods, not call sites" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        validate(node)
        validate(node)
        validate(node)
        validate(node)
      end
    RUBY
  end

  test "ignores block parameters, tracking only method parameters and locals" do
    assert_no_offense <<~RUBY
      def rewrite(nodes)
        nodes.each do |node|
          a(node)
          b(node)
          c(node)
          d(node)
        end
      end
    RUBY
  end

  test "follows a value transitively down a pipeline across methods" do
    offenses = assert_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          decorate(value)
          persist(value)
          index(value)
        end
      end
    RUBY
    assert_includes offenses.first.message, "`node` is threaded through 4 methods"
  end

  test "follows a value through a long chain of single-argument hops" do
    offenses = assert_offense <<~RUBY
      class Pipe
        def first(input)
          second(input)
        end

        def second(a)
          third(a)
        end

        def third(b)
          fourth(b)
        end

        def fourth(c)
          sink(c)
        end
      end
    RUBY
    assert_includes offenses.first.message, "`input` is threaded through 4 methods"
  end

  test "does not follow the flow into a recursive method" do
    assert_no_offense <<~RUBY
      class Tree
        def start(node)
          walk(node)
        end

        def walk(node)
          left(node)
          right(node)
          walk(node)
        end
      end
    RUBY
  end

  test "does not report the parameter of a recursive walker" do
    assert_no_offense <<~RUBY
      class Tree
        def walk(node)
          visit(node)
          decorate(node)
          persist(node)
          walk(node)
        end
      end
    RUBY
  end

  test "ignores a value shadowed by a block parameter in a callee" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(item)
          a(item)
          list.each do |item|
            inner(item)
          end
        end
      end
    RUBY
  end

  test "ignores a value cycling through mutually recursive methods" do
    assert_no_offense <<~RUBY
      class Walker
        def walk(node)
          before(node)
          descend(node)
          after(node)
          log(node)
        end

        def descend(node)
          walk(node)
        end
      end
    RUBY
  end
end
