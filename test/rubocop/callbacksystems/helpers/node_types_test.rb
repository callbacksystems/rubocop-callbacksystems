require "test_helper"

class RuboCop::Callbacksystems::Helpers::NodeTypesTest < HelpersTestCase
  test "declaration_macro? returns true for a receiver-less declaration macro" do
    node = processed_source("delegate :size, to: :node").ast

    assert Helpers.declaration_macro?(node)
  end

  test "declaration_macro? returns false for other receiver-less calls" do
    node = processed_source("validates :name").ast

    assert_not Helpers.declaration_macro?(node)
  end

  test "declaration_macro? returns false when the macro has a receiver" do
    node = processed_source("other.attr_reader :node").ast

    assert_not Helpers.declaration_macro?(node)
  end

  test "attribute_macro? returns true for every attribute macro" do
    macros = %w[ attr_reader attr_writer attr_accessor attribute class_attribute has_secure_password has_secure_token ]

    macros.each { assert Helpers.attribute_macro?(processed_source("#{it} :name").ast), it }

    assert_not Helpers.attribute_macro?(processed_source("delegate :name, to: :board").ast)
  end

  test "bare_send? returns true for receiver-less send" do
    node = processed_source("foo(1)").ast

    assert Helpers.bare_send?(node)
  end

  test "bare_send? returns false when there is a receiver" do
    node = processed_source("obj.foo").ast

    assert_not Helpers.bare_send?(node)
  end

  test "bare_send? returns false for non-send nodes" do
    node = processed_source("42").ast

    assert_not Helpers.bare_send?(node)
  end

  test "bare_send? returns false for nil" do
    assert_not Helpers.bare_send?(nil)
  end

  test "delegate_macro? returns true only for a receiver-less delegate" do
    assert Helpers.delegate_macro?(processed_source("delegate :name, to: :board").ast)
    assert Helpers.delegate_macro?(processed_source("delegate_missing_to :board").ast)
    assert_not Helpers.delegate_macro?(processed_source("attr_reader :name").ast)
    assert_not Helpers.delegate_macro?(processed_source("self.delegate :name, to: :board").ast)
  end

  test "mixin_macro? returns true for a receiver-less mixin macro" do
    node = processed_source("include Enumerable").ast

    assert Helpers.mixin_macro?(node)
  end

  test "mixin_macro? returns false for other receiver-less calls" do
    node = processed_source("delegate :size, to: :node").ast

    assert_not Helpers.mixin_macro?(node)
  end

  test "mixin_macro? returns false when the macro has a receiver" do
    node = processed_source("other.include Enumerable").ast

    assert_not Helpers.mixin_macro?(node)
  end

  test "association_macro? returns true for every receiver-less association macro" do
    macros = %w[
      belongs_to has_many has_one has_and_belongs_to_many delegated_type
      has_one_attached has_many_attached has_rich_text accepts_nested_attributes_for
    ]

    macros.each { assert Helpers.association_macro?(processed_source("#{it} :board").ast), it }
  end

  test "association_macro? returns false for other receiver-less macros" do
    node = processed_source("validates :name, presence: true").ast

    assert_not Helpers.association_macro?(node)
  end

  test "call_on_self? recognizes implicit and explicit self calls" do
    assert Helpers.call_on_self?(processed_source("work").ast)
    assert Helpers.call_on_self?(processed_source("self.work").ast)
  end

  test "call_on_self? rejects another receiver and a non-call" do
    assert_not Helpers.call_on_self?(processed_source("worker.work").ast)
    assert_not Helpers.call_on_self?(processed_source("42").ast)
    assert_not Helpers.call_on_self?(nil)
  end

  test "singleton_section? returns true for class << self" do
    node = processed_source("class << self\nend").ast

    assert Helpers.singleton_section?(node)
  end

  test "singleton_section? returns false for a singleton class of another object" do
    node = processed_source("class << other\nend").ast

    assert_not Helpers.singleton_section?(node)
  end

  test "singleton_section? returns false for nil" do
    assert_not Helpers.singleton_section?(nil)
  end

  test "structural_self? recognizes the receiver of a singleton class" do
    node = processed_source("class << self; end").ast.identifier

    assert Helpers.structural_self?(node)
  end

  test "structural_self? recognizes the receiver of a singleton method" do
    node = processed_source("def self.process; end").ast.receiver

    assert Helpers.structural_self?(node)
  end

  test "structural_self? rejects self returned from a singleton body" do
    [ "class << self; self; end", "def self.process; self; end" ].each do |source|
      assert_not Helpers.structural_self?(processed_source(source).ast.body)
    end
  end

  test "structural_self? rejects a value outside singleton definitions" do
    assert_not Helpers.structural_self?(processed_source("self").ast)
    assert_not Helpers.structural_self?(processed_source("self.process").ast.receiver)
  end

  test "definition_identifier? returns true for the constant a class definition names" do
    node = processed_source("class Foo::Bar\nend").ast.identifier

    assert Helpers.definition_identifier?(node)
  end

  test "definition_identifier? returns false for a superclass reference" do
    node = processed_source("class Foo < Bar\nend").ast.parent_class

    assert_not Helpers.definition_identifier?(node)
  end

  test "definition_identifier? returns false for a constant read in a body" do
    node = processed_source("class Foo\n  Bar\nend").ast.body

    assert_not Helpers.definition_identifier?(node)
  end

  test "reads_of lists the reads of a local variable within a scope" do
    scope = processed_source("value = 1\nvalue + value\nother").ast

    assert_equal 2, Helpers.reads_of(:value, within: scope).size
  end

  test "reads_of keeps an instance variable apart from a local of the same name" do
    scope = processed_source("count = 1\n@count + count").ast

    assert_equal [ :ivar ], Helpers.reads_of(:@count, within: scope).map(&:type)
  end

  test "reads_of is empty for a nil scope" do
    assert_empty Helpers.reads_of(:value, within: nil)
  end

  test "nodes_in returns the nodes of the given types" do
    tree = processed_source("class Foo\n  def bar; end\n  def baz; end\nend").ast

    assert_equal [ :bar, :baz ], Helpers.nodes_in(tree, :def).map(&:method_name)
  end

  test "nodes_in returns nothing for the empty file, which parses to no tree" do
    assert_empty Helpers.nodes_in(processed_source("").ast, :def)
  end

  test "reads_variable? returns true when the node reads the given local variable" do
    ast = processed_source("value = 1\nvalue").ast
    lvar_node = ast.each_node(:lvar).first

    assert Helpers.reads_variable?(lvar_node, :value)
  end

  test "reads_variable? returns true when the node reads the given instance variable" do
    node = processed_source("@count").ast

    assert Helpers.reads_variable?(node, :@count)
  end

  test "reads_variable? returns false for a different variable name" do
    node = processed_source("@count").ast

    assert_not Helpers.reads_variable?(node, :@total)
  end

  test "reads_variable? returns false for non-variable nodes" do
    node = processed_source("foo").ast

    assert_not Helpers.reads_variable?(node, :foo)
  end

  test "reads_variable? returns false for nil" do
    assert_not Helpers.reads_variable?(nil, :value)
  end

  test "definition_nodes_in lists every class, module and singleton section in the tree" do
    ast = processed_source("module A\n  class B\n    class << self; end\n  end\nend\nfoo\n").ast

    assert_equal %i[ module class sclass ], Helpers.definition_nodes_in(ast).map(&:type)
  end

  test "definition_nodes_in is empty for no tree" do
    assert_empty Helpers.definition_nodes_in(nil)
  end

  test "reads_as_string? returns true for string literals and calls known to return strings" do
    assert Helpers.reads_as_string?(processed_source('"text"').ast)
    assert Helpers.reads_as_string?(processed_source("name.upcase").ast)
  end

  test "reads_as_string? returns false for an array-producing call and nil" do
    assert_not Helpers.reads_as_string?(processed_source('text.split(",")').ast)
    assert_not Helpers.reads_as_string?(nil)
  end

  test "reads_as? returns true for a node of one of the given literal types" do
    node = processed_source('"a text"').ast

    assert Helpers.reads_as?(node, literals: %i[ str dstr ], methods: [])
  end

  test "reads_as? returns true for a call to one of the given methods" do
    node = processed_source("name.strip").ast

    assert Helpers.reads_as?(node, literals: [], methods: %i[ strip ])
  end

  test "reads_as? returns false for a node neither list names" do
    node = processed_source("parts.split(\",\")").ast

    assert_not Helpers.reads_as?(node, literals: %i[ str ], methods: %i[ strip ])
  end

  test "reads_as_array? recognizes array literals and core Array construction" do
    sources = [ "[]", "%i[one two]", "Array.new", "Array[one]", "::Array.new(2)" ]

    assert sources.all? { Helpers.reads_as_array?(processed_source(it).ast) }
  end

  test "reads_as_array? rejects unknown values and namespaced Array lookalikes" do
    sources = [ "items", "build_items", "Domain::Array.new", '"items"' ]

    assert sources.none? { Helpers.reads_as_array?(processed_source(it).ast) }
    assert_not Helpers.reads_as_array?(nil)
  end

  test "call_of returns the call a block hangs on" do
    node = processed_source("items.each { it }").ast

    assert_equal :each, Helpers.call_of(node).method_name
  end

  test "call_of hands back a node that is not a block as it is" do
    node = processed_source("items.each").ast

    assert_same node, Helpers.call_of(node)
  end

  test "any_block_type? returns true for block nodes" do
    ast = processed_source("items.each { |x| x }").ast
    block_node = ast.each_node(:block).first

    assert Helpers.any_block_type?(block_node)
  end

  test "any_block_type? returns false for non-block nodes" do
    ast = processed_source("foo").ast

    assert_not Helpers.any_block_type?(ast)
  end

  test "any_block_type? returns false for nil" do
    assert_not Helpers.any_block_type?(nil)
  end

  test "core_constant? recognizes an unqualified or explicitly root-qualified constant" do
    assert Helpers.core_constant?(processed_source("Hash").ast)
    assert Helpers.core_constant?(processed_source("::Hash").ast)
  end

  test "core_constant? rejects a namespaced constant, another node or nil" do
    assert_not Helpers.core_constant?(processed_source("Foo::Hash").ast)
    assert_not Helpers.core_constant?(processed_source("factory.Hash").ast)
    assert_not Helpers.core_constant?(nil)
  end

  test "empty_collection_literal? returns true for an empty array or hash literal" do
    assert Helpers.empty_collection_literal?(processed_source("[]").ast)
    assert Helpers.empty_collection_literal?(processed_source("{}").ast)
  end

  test "empty_collection_literal? returns false for a filled literal, another node, or nil" do
    assert_not Helpers.empty_collection_literal?(processed_source("[ 1 ]").ast)
    assert_not Helpers.empty_collection_literal?(processed_source("Array.new").ast)
    assert_not Helpers.empty_collection_literal?(nil)
  end

  test "loop_block? returns true for a loop block" do
    ast = processed_source("loop { work }").ast

    assert Helpers.loop_block?(ast)
  end

  test "loop_block? returns false for any other block" do
    ast = processed_source("items.each { work }").ast

    assert_not Helpers.loop_block?(ast)
  end

  test "returned_expression_of unwraps a return statement" do
    node = processed_source("return value").ast

    assert_equal "value", Helpers.returned_expression_of(node).source
  end

  test "returned_expression_of hands back a plain expression as it is" do
    node = processed_source("value").ast

    assert_same node, Helpers.returned_expression_of(node)
  end

  test "hash_pairs_of lists the pairs of every hash argument" do
    node = processed_source("resources :users, module: :admin, only: :index").ast

    assert_equal %w[ module only ], Helpers.hash_pairs_of(node).map { it.key.value.to_s }
  end

  test "hash_pairs_of is empty without a hash argument" do
    assert_empty Helpers.hash_pairs_of(processed_source("resources :users").ast)
  end

  test "top_level_definitions_in lists the classes and modules a file opens with" do
    ast = processed_source("class A; end\nmodule B; end\nfoo\n").ast

    assert_equal %w[ A B ], Helpers.top_level_definitions_in(ast).map { it.identifier.source }
  end

  test "top_level_definitions_in wraps a lone definition" do
    ast = processed_source("class A; end").ast

    assert_equal [ ast ], Helpers.top_level_definitions_in(ast)
  end

  test "top_level_definitions_in is empty for anything else" do
    assert_empty Helpers.top_level_definitions_in(processed_source("foo").ast)
    assert_empty Helpers.top_level_definitions_in(nil)
  end

  test "top_level_definitions_in walks a file deeper than Ruby's call stack" do
    identifier = RuboCop::AST::Node.new(:const, [ nil, :User ])
    definition = RuboCop::AST::Node.new(:class, [ identifier, nil, nil ])
    tree = 5_000.times.reduce(definition) { |nested, _| RuboCop::AST::Node.new(:begin, [ nested ]) }

    assert_equal [ definition ], Helpers.top_level_definitions_in(tree)
  end

  test "top-level definitions return an enumerator without a block" do
    ast = processed_source("class User; end").ast
    definitions = RuboCop::Callbacksystems::Helpers::NodeTypes::TopLevelDefinitions.new(ast)

    assert_instance_of Enumerator, definitions.each
    assert_equal [ ast ], definitions.each.to_a
  end
end
