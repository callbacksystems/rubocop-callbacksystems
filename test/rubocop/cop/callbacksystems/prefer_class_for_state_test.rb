require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferClassForStateTest < CopTestCase
  include SourceParsing

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

  test "tracks multiple values in one method independently" do
    offenses = assert_offense <<~RUBY, count: 2
      def rewrite(first, second)
        validate_first(first)
        decorate_first(first)
        persist_first(first)
        index_first(first)
        validate_second(second)
        decorate_second(second)
        persist_second(second)
        index_second(second)
      end
    RUBY

    assert_equal [ "first", "second" ], offenses.map { it.location.source }
  end

  test "threading calls traverse a method once for every indexed value" do
    method = method_named(<<~RUBY, :rewrite)
      def rewrite(first, second = default)
        validate(first)
        combine(first, second)
        persist(second)
      end
    RUBY
    traversals = 0
    method_probe = Object.new
    method_probe.define_singleton_method(:each_descendant) do |*types|
      traversals += 1
      method.each_descendant(*types)
    end
    method_probe.define_singleton_method(:body) { method.body }
    calls = self.class.cop_class::ThreadingCalls.new(method_probe)

    assert_equal %i[ validate combine ], calls.named("first").map(&:method_name)
    assert_equal %i[ combine persist ], calls.named("second").map(&:method_name)
    assert_equal %i[ validate combine persist ], calls.body_method_names.to_a
    assert_equal 1, traversals
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

  test "stops following a value at a callee taking it through a splat" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(*nodes)
          a(nodes)
          b(nodes)
          c(nodes)
        end
      end
    RUBY
  end

  test "stops following a value whose position follows a splatted argument" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node, prefix)
          process(*prefix, node)
        end

        def process(prefix, value)
          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "stops following a value into an optional parameter" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value = default)
          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "stops following a value whose argument has no corresponding parameter" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(prefix, node)
        end

        def process(prefix)
          validate(prefix)
          decorate(prefix)
          persist(prefix)
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

  test "does not merge the flows of separate assignments to the same local" do
    assert_no_offense <<~RUBY
      def rewrite(input)
        node = parse(input)
        validate(node)
        decorate(node)
        node = fallback(input)
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not follow a parameter after it is reassigned" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        validate(node)
        decorate(node)
        node = fallback
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not follow a parameter reassigned from inside a block" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        records.each { node = fallback }
        validate(node)
        decorate(node)
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not follow a parameter reassigned while a singleton method receiver is evaluated" do
    assert_no_offense <<~RUBY
      def rewrite(node)
        def (node = fallback).run; end
        validate(node)
        decorate(node)
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not follow a parameter assigned by pattern matching" do
    assert_no_offense <<~RUBY
      def rewrite(node, input)
        input => { node: }
        validate(node)
        decorate(node)
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not treat a local followed by a pattern assignment as stable" do
    assert_no_offense <<~RUBY
      def rewrite(input)
        node = parse(input)
        input => { node: }
        validate(node)
        decorate(node)
        persist(node)
        index(node)
      end
    RUBY
  end

  test "does not follow a parameter reassigned in a callee" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          a(value)
          value = fallback
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "does not follow a parameter reassigned by a capturing block in a callee" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          records.each { value = fallback }
          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "does not follow a parameter assigned by pattern matching in a callee" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          input => { value: }
          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "follows a parameter when an explicitly block-local value is reassigned" do
    assert_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          records.each { |; value| value = fallback }
          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "follows a parameter when only a nested method reassigns that name" do
    assert_offense <<~RUBY
      class Compiler
        def rewrite(node)
          process(node)
        end

        def process(value)
          def nested
            value = fallback
          end

          a(value)
          b(value)
          c(value)
        end
      end
    RUBY
  end

  test "does not follow an instance value into a singleton method with the same name" do
    assert_no_offense <<~RUBY
      class Compiler
        def rewrite(node)
          prepare(node)
        end

        def self.prepare(node)
          validate(node)
          decorate(node)
          persist(node)
        end
      end
    RUBY
  end

  test "does not follow a singleton value into an instance method with the same name" do
    assert_no_offense <<~RUBY
      class Compiler
        def self.rewrite(node)
          prepare(node)
        end

        def prepare(node)
          validate(node)
          decorate(node)
          persist(node)
        end
      end
    RUBY
  end

  test "follows a singleton value through methods in a singleton section" do
    assert_offense <<~RUBY
      class Compiler
        class << self
          def rewrite(node)
            prepare(node)
          end

          def prepare(node)
            validate(node)
            decorate(node)
            persist(node)
          end
        end
      end
    RUBY
  end

  test "does not follow a definition on another singleton receiver into this class" do
    assert_no_offense <<~RUBY
      class Compiler
        def Other.rewrite(node)
          prepare(node)
        end

        def self.prepare(node)
          validate(node)
          decorate(node)
          persist(node)
        end
      end
    RUBY
  end

  test "does not follow this class into a definition on another singleton receiver" do
    assert_no_offense <<~RUBY
      class Compiler
        def self.rewrite(node)
          prepare(node)
        end

        def Other.prepare(node)
          validate(node)
          decorate(node)
          persist(node)
        end
      end
    RUBY
  end

  test "keeps a singleton definition inside an eigenclass in its higher-order domain" do
    assert_no_offense <<~RUBY
      class Compiler
        class << self
          def self.rewrite(node)
            prepare(node)
          end

          def prepare(node)
            validate(node)
            decorate(node)
            persist(node)
          end
        end
      end
    RUBY
  end

  test "keeps singleton classes for different expressions in separate domains" do
    assert_no_offense <<~RUBY
      class Compiler
        class << FIRST
          def rewrite(node)
            prepare(node)
          end

        class << SECOND
          def prepare(node)
            validate(node)
            decorate(node)
            persist(node)
          end
        end
      end
    RUBY
  end

  test "does not resolve a method in a class builder against the enclosing class" do
    assert_no_offense <<~RUBY
      class Compiler
        Handler = Class.new(BaseHandler) do
          def rewrite(node)
            prepare(node)
          end
        end

        def prepare(value)
          validate(value)
          decorate(value)
          persist(value)
        end
      end
    RUBY
  end

  test "follows a long pipeline without growing the Ruby call stack" do
    assert_offense long_pipeline(1_600), count: 1_597
  end

  test "assignment enumeration preserves source order without requiring a block" do
    body = method_body <<~RUBY
      def rewrite
        first = parse
        input => { second: }
      end
    RUBY
    assignments = self.class.cop_class::MethodAssignments::AssignmentsWithin.new(body).each

    assert_instance_of Enumerator, assignments
    assert_equal %i[ first second ], assignments.map { it.children.first }
  end

  private
    def long_pipeline(length)
      methods = length.times.map do |index|
        target = index.next < length ? "step_#{index.next}(value)" : "sink(value)"
        "  def step_#{index}(value); #{target}; end\n"
      end

      "class Pipeline\n#{methods.join}end\n"
    end
end
