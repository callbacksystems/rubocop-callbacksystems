require "test_helper"

class RuboCop::Callbacksystems::Helpers::BodiesTest < HelpersTestCase
  test "assignment_count counts unique instance variable assignments" do
    body = class_body(<<~RUBY)
      class Foo
        def initialize
          @a = 1
          @b = 2
          @a = 3
        end
      end
    RUBY

    assert_equal 2, Helpers.assignment_count(body, :ivasgn)
  end

  test "assignment_count counts unique local variable assignments" do
    body = class_body(<<~RUBY)
      class Foo
        def initialize
          a = 1
          b = 2
          c = 3
        end
      end
    RUBY

    assert_equal 3, Helpers.assignment_count(body, :lvasgn)
  end

  test "assignment_count counts pattern bindings and deduplicates them with ordinary assignments" do
    body = method_body(<<~RUBY)
      def process(input)
        first = build
        input => { first:, second:, third: }
      end
    RUBY

    assert_equal 3, Helpers.assignment_count(body, :lvasgn, :match_var)
  end

  test "assignment_count returns 0 for nil body" do
    assert_equal 0, Helpers.assignment_count(nil, :ivasgn)
  end

  test "assignment_count excludes assignments inside deferred callable and method bodies" do
    body = method_body <<~RUBY
      def configure
        own = build
        proc { first = 1 }
        Proc.new { second = 2 }
        define_method(:perform) { third = 3 }
      end
    RUBY

    assert_equal 1, Helpers.assignment_count(body, :lvasgn)
  end

  test "assignment_count keeps assignments evaluated while a deferred callable is built" do
    body = method_body("def configure; proc(value = build) { deferred = 1 }; end")

    assert_equal 1, Helpers.assignment_count(body, :lvasgn)
  end

  test "assignment_count keeps assignments evaluated while lexical definitions are opened" do
    body = method_body <<~RUBY
      def configure
        own = build
        def (singleton = build).call
          hidden = build
        end
        class << (eigenclass = build)
          also_hidden = build
        end
      end
    RUBY

    assert_equal 3, Helpers.assignment_count(body, :lvasgn)
  end

  test "assignment_count walks a body deeper than Ruby's call stack" do
    assignment = RuboCop::AST::AsgnNode.new(:lvasgn, [ :value, RuboCop::AST::Node.new(:nil) ])
    body = 2_000.times.reduce(assignment) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }

    assert_equal 1, Helpers.assignment_count(body, :lvasgn)
  end

  test "immediate_inputs_of returns the receiver and arguments evaluated before a deferred block" do
    block = processed_source("receiver.install(argument) { deferred }").ast

    assert_equal %w[ receiver argument ], Helpers.immediate_inputs_of(block).map(&:source)
  end

  test "immediate_inputs_of returns only the expressions evaluated while lexical definitions open" do
    definitions = processed_source(<<~RUBY).ast.children
      def target.run; hidden; end
      class << owner; hidden; end
      class Child < parent; hidden; end
      def instance_method; hidden; end
      module Namespace; hidden; end
    RUBY

    assert_equal [ [ "target" ], [ "owner" ], [ "Child", "parent" ], [], [] ],
      definitions.map { Helpers.immediate_inputs_of(it).map(&:source) }
  end

  test "lexical_definition? recognizes definitions that introduce a lexical boundary" do
    nodes = processed_source(<<~RUBY).ast.children
      def one; end
      def self.two; end
      class Three; end
      module Four; end
      class << self; end
    RUBY

    assert nodes.all? { Helpers.lexical_definition?(it) }
    assert_not Helpers.lexical_definition?(processed_source("work").ast)
  end

  test "statements_before lists the statements above the node in its body" do
    body = method_body("def foo\n  a\n  b\n  c\nend")

    assert_equal %i[ a b ], Helpers.statements_before(body.children.last).map(&:method_name)
  end

  test "statements_before lists statements inside an explicit begin" do
    body = method_body("def foo\n  begin\n    a\n    b\n    c\n  end\nend")

    assert_equal %i[ a b ], Helpers.statements_before(body.children.last).map(&:method_name)
  end

  test "statements_before is empty for the first statement or a lone one" do
    body = method_body("def foo\n  a\n  b\nend")

    assert_empty Helpers.statements_before(body.children.first)
    assert_empty Helpers.statements_before(method_body("def foo\n  a\nend"))
  end

  test "direct_definitions_in returns the definitions of the given type at the top of a body" do
    body = class_body("class Foo\n  def bar; end\n  def self.baz; end\n  attr_reader :qux\nend")

    assert_equal [ :bar ], Helpers.direct_definitions_in(body, :def).map(&:method_name)
    assert_equal [ :baz ], Helpers.direct_definitions_in(body, :defs).map(&:method_name)
  end

  test "direct_definitions_in returns empty for nil body" do
    assert_empty Helpers.direct_definitions_in(nil, :def)
  end

  test "statements_in unwraps begin into its children" do
    body = method_body(<<~RUBY)
      def foo
        a
        b
        c
      end
    RUBY

    assert_equal %i[ a b c ], Helpers.statements_in(body).map(&:method_name)
  end

  test "statements_in wraps a single statement in an array" do
    body = method_body("def foo; bar; end")

    assert_equal [ :bar ], Helpers.statements_in(body).map(&:method_name)
  end

  test "statements_in returns empty for nil body" do
    assert_empty Helpers.statements_in(nil)
  end

  test "runs_in groups the consecutive statements the block accepts" do
    body = method_body(<<~RUBY)
      def foo
        a
        b
        skip
        c
        skip
      end
    RUBY

    runs = Helpers.runs_in(body) { !it.method?(:skip) }

    assert_equal [ %i[ a b ], %i[ c ] ], runs.map { it.map(&:method_name) }
  end

  test "runs_in keeps a lone accepted statement as a run of one" do
    body = method_body("def foo; bar; end")

    assert_equal [ [ :bar ] ], Helpers.runs_in(body) { true }.map { it.map(&:method_name) }
  end

  test "runs_in is empty when no statement is accepted or the body is nil" do
    assert_empty Helpers.runs_in(method_body("def foo; bar; end")) { false }
    assert_empty Helpers.runs_in(nil) { true }
  end

  test "receiverless_method_names_in collects bare sends from the body" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz(1)
        self.qux
        SomeConst.zap
      end
    RUBY

    assert_equal [ :bar, :baz ], Helpers.receiverless_method_names_in(body)
  end

  test "receiverless_method_names_in traverses nested expressions" do
    body = method_body(<<~RUBY)
      def foo
        if condition?
          process
        end
      end
    RUBY

    assert_equal [ :condition?, :process ], Helpers.receiverless_method_names_in(body)
  end

  test "receiverless_method_names_in returns empty for nil body" do
    assert_empty Helpers.receiverless_method_names_in(nil)
  end

  test "first_statement_in returns single statement from simple body" do
    body = method_body("def foo; bar; end")

    assert_equal :send, Helpers.first_statement_in(body).type
  end

  test "first_statement_in returns first of multiple statements" do
    body = method_body("def foo; bar; baz; end")

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in unwraps rescue" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in unwraps ensure" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :bar, Helpers.first_statement_in(body).method_name
  end

  test "first_statement_in returns nil for nil body" do
    assert_nil Helpers.first_statement_in(nil)
  end

  test "last_statement_in returns single statement from simple body" do
    body = method_body("def foo; bar; end")

    assert_equal :send, Helpers.last_statement_in(body).type
  end

  test "last_statement_in returns last of multiple statements" do
    body = method_body("def foo; bar; baz; end")

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in unwraps rescue" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      rescue
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in unwraps ensure" do
    body = method_body(<<~RUBY)
      def foo
        bar
        baz
      ensure
        nil
      end
    RUBY

    assert_equal :baz, Helpers.last_statement_in(body).method_name
  end

  test "last_statement_in returns nil for nil body" do
    assert_nil Helpers.last_statement_in(nil)
  end

  test "edge statements unwrap a body deeper than Ruby's call stack" do
    statement = RuboCop::AST::SendNode.new(:send, [ nil, :work ])
    body = 5_000.times.reduce(statement) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }

    assert_same statement, Helpers.first_statement_in(body)
    assert_same statement, Helpers.last_statement_in(body)
  end

  test "direct_method_nodes_in returns method defs at the top of a class body" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end
        def baz; end
      end
    RUBY

    assert_equal [ :bar, :baz ], Helpers.direct_method_nodes_in(body).map(&:method_name)
  end

  test "direct_method_nodes_in ignores defs inside nested classes" do
    body = class_body(<<~RUBY)
      class Foo
        def bar; end

        class Inner
          def baz; end
        end
      end
    RUBY

    assert_equal [ :bar ], Helpers.direct_method_nodes_in(body).map(&:method_name)
  end

  test "direct_method_nodes_in returns the methods a singleton class body holds" do
    body = class_body(<<~RUBY)
      class Foo
        class << self
          def bar
          end
        end
      end
    RUBY

    assert_equal [ :bar ], Helpers.direct_method_nodes_in(body).map(&:method_name)
  end

  test "direct_method_nodes_in accepts an empty singleton class body" do
    body = class_body("class Foo\n  class << self; end\nend")

    assert_empty Helpers.direct_method_nodes_in(body)
  end

  test "direct_method_nodes_in returns empty for nil body" do
    assert_empty Helpers.direct_method_nodes_in(nil)
  end

  test "direct_method_nodes_in walks a body deeper than Ruby's call stack" do
    method = RuboCop::AST::Node.new(:def, [ :work, RuboCop::AST::Node.new(:args), nil ])
    body = 2_000.times.reduce(method) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }

    assert_equal [ method ], Helpers.direct_method_nodes_in(body)
  end

  test "direct method nodes return an enumerator without a block" do
    body = class_body("class Foo\n  def work; end\nend")
    definitions = RuboCop::Callbacksystems::Helpers::Bodies::DirectMethodNodes.new(body)

    assert_instance_of Enumerator, definitions.each
    assert_equal [ :work ], definitions.each.map(&:method_name)
  end

  test "scoped assignments return an enumerator without a block" do
    body = method_body("def work; value = build; end")
    assignments = RuboCop::Callbacksystems::Helpers::Bodies::ScopedAssignments.new(body, [ :lvasgn ])

    assert_instance_of Enumerator, assignments.each
    assert_equal [ :value ], assignments.each.map(&:name)
  end
end
