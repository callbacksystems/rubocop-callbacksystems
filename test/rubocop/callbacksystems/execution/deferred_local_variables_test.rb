require "test_helper"

class RuboCop::Callbacksystems::Execution::DeferredLocalVariablesTest < ActiveSupport::TestCase
  include SourceParsing

  test "include? finds reads and writes captured by deferred callable bodies" do
    body = method_body(<<~RUBY)
      def perform
        first = build
        fourth = build
        lambda { use(first) }
        proc { second = value }
        Proc.new { payload => { third: } }
        define_method(:later) { use(fourth) }
      end
    RUBY
    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

    assert_includes variables, :first
    assert_includes variables, :second
    assert_includes variables, :third
    assert_includes variables, :fourth
  end

  test "include? leaves variables used only by immediately executed blocks out" do
    body = method_body("def perform; value = build; items.each { use(value) }; end")

    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

    assert_not variables.include?(:value)
  end

  test "include? leaves variables shadowed by block parameters out" do
    body = method_body("def perform; callback = ->(value) { use(value) }; end")

    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

    assert_not variables.include?(:value)
  end

  test "include? ignores an anonymous block parameter while retaining outer captures" do
    body = method_body("def perform; value = build; callback = proc { |*| use(value) }; end")

    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

    assert_includes variables, :value
  end

  test "include? follows captures beside implicit numbered and it parameters" do
    [ "_1", "it" ].each do |parameter|
      body = method_body("def perform; value = build; callback = proc { use(#{parameter}); use(value) }; end")
      variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

      assert_includes variables, :value
      assert_not variables.include?(parameter.to_sym)
    end
  end

  test "include? leaves occurrences across a lexical boundary out" do
    body = method_body("def perform; value = build; callback = -> { Class.new { def call; use(value); end } }; end")

    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(body)

    assert_not variables.include?(:value)
  end

  test "include? finds deferred captures in expressions that open lexical definitions" do
    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(processed_source(<<~RUBY).ast)
      target = build_target
      superclass = build_superclass
      proc { def target.run; end }
      proc { class << target; end }
      proc { class Child < superclass; end }
    RUBY

    assert_includes variables, :target
    assert_includes variables, :superclass
  end

  test "include? walks deferred bodies deeper than Ruby's call stack" do
    read = RuboCop::AST::VarNode.new(:lvar, [ :value ])
    body = 5_000.times.reduce(read) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }
    callable = RuboCop::AST::BlockNode.new \
      :block,
      [ RuboCop::AST::SendNode.new(:send, [ nil, :proc ]), RuboCop::AST::ArgsNode.new(:args), body ]

    variables = RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(callable)

    assert_includes variables, :value
  end

  test "traversal returns an enumerator without a block" do
    body = method_body("def perform; value = build; callback = proc { use(value) }; end")
    traversal = RuboCop::Callbacksystems::Execution::DeferredLocalVariables::Traversal.new(body)

    assert_instance_of Enumerator, traversal.each
    assert_equal [ :value ], traversal.each.to_a
  end
end
