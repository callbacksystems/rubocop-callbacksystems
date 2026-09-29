require "test_helper"

class RuboCop::Callbacksystems::Helpers::VariablesTest < HelpersTestCase
  test "deferred_callable_block? recognizes Kernel callables and Proc construction" do
    sources = [ "-> { work }", "lambda { work }", "proc { work }", "Kernel.proc { work }", "Proc.new { work }" ]

    assert sources.all? { Helpers.deferred_callable_block?(processed_source(it).ast) }
  end

  test "deferred_callable_block? rejects an ordinary block or namespaced lookalikes" do
    sources = [
      "items.each { work }", "factory.proc { work }", "Foo::Kernel.lambda { work }", "Foo::Proc.new { work }"
    ]

    assert sources.none? { Helpers.deferred_callable_block?(processed_source(it).ast) }
  end

  test "method_definition_block? recognizes instance and singleton method definitions" do
    assert Helpers.method_definition_block?(processed_source("define_method(:run) { work }").ast)
    assert Helpers.method_definition_block?(processed_source("object.define_singleton_method(:run) { work }").ast)
    assert_not Helpers.method_definition_block?(processed_source("items.each { work }").ast)
  end

  test "variable_name_of reads ordinary assignments and pattern bindings" do
    source = processed_source("local = value; case payload; in { name: bound }; end")

    assert_equal :local, Helpers.variable_name_of(source.ast.each_node(:lvasgn).first)
    assert_equal :bound, Helpers.variable_name_of(source.ast.each_node(:match_var).first)
  end

  test "conditional_return_of_block_argument? recognizes only an immediate block argument" do
    block = processed_source(<<~RUBY).ast
      items.each do |item|
        return item if item.valid?
      end
    RUBY

    assert Helpers.conditional_return_of_block_argument?(block.body.if_branch, block: block)
  end

  test "conditional_return_of_block_argument? rejects transformed, empty, and rebound returns" do
    block = processed_source(<<~RUBY).ast
      items.each do |item|
        return decorate(item) if item.valid?
        return if item.missing?
        candidates.then do |item|
          return item if item.ready?
        end
      end
    RUBY
    returns = block.each_descendant(:return).to_a

    assert returns.none? { Helpers.conditional_return_of_block_argument?(it, block: block) }
  end

  test "name_rebound_between? is true when an inner block binds the name again" do
    method = method_named("def run(node); items.each { |node| use(node) }; end", :run)
    read = method.each_descendant(:lvar).find { it.name == :node }

    assert Helpers.name_rebound_between?(:node, node: read, boundary: method)
  end

  test "name_rebound_between? is false when an intervening block captures the existing name" do
    method = method_named("def run(node); items.each { use(node) }; end", :run)
    read = method.each_descendant(:lvar).find { it.name == :node }

    assert_not Helpers.name_rebound_between?(:node, node: read, boundary: method)
  end

  test "name_rebound_between? leaves the boundary's own binding out" do
    block = processed_source("items.each { |item| use(item) }").ast
    read = block.each_descendant(:lvar).first

    assert_not Helpers.name_rebound_between?(:item, node: read, boundary: block)
  end
end
