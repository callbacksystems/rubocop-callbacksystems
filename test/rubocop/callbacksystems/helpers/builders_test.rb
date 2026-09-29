require "test_helper"

class RuboCop::Callbacksystems::Helpers::BuildersTest < HelpersTestCase
  test "self_preserved_between? rejects state inside core class and module builder bodies" do
    builders = processed_source(<<~RUBY).ast.children
      Class.new { @class_state = build }
      Module.new { @module_state = build }
      Struct.new(:value) { @struct_state = build }
      Data.define(:value) { @data_state = build }
    RUBY

    assert builders.none? { |block|
      Helpers.self_preserved_between?(block.body, boundary: block.each_ancestor.first)
    }
  end

  test "self_preserved_between? keeps ordinary and deferred blocks on their lexical self" do
    blocks = processed_source(<<~RUBY).ast.children
      items.each { @item = it }
      lambda { @later = build }
      proc { @other = build }
    RUBY

    assert blocks.all? { |block|
      Helpers.self_preserved_between?(block.body, boundary: block.each_ancestor.first)
    }
  end

  test "self_preserved_between? keeps receivers and arguments evaluated before rebound bodies" do
    blocks = processed_source(<<~RUBY).ast.children
      Class.new(@parent = parent) { @inner = build }
      receiver(@target = object).instance_exec(@argument = value) { @evaluated = build }
    RUBY

    assignments = blocks.flat_map { it.each_descendant(:ivasgn).to_a }
    preservation_by_name = assignments.to_h do |assignment|
      [ assignment.name, Helpers.self_preserved_between?(assignment, boundary: nil) ]
    end

    assert_equal({
      "@parent": true, "@inner": false, "@target": true, "@argument": true, "@evaluated": false
    }, preservation_by_name)
  end

  test "self_preserved_between? accepts namespaced builder lookalikes" do
    block = processed_source("Domain::Class.new { @value = build }").ast

    assert Helpers.self_preserved_between?(block.body, boundary: block.each_ancestor.first)
  end

  test "self_preserved_between? rejects bodies evaluated against an explicit receiver" do
    blocks = processed_source(<<~RUBY).ast.children
      object.instance_eval { @one = build }
      object.instance_exec(argument) { @two = build }
      object.class_eval { @three = build }
      object.class_exec(argument) { @four = build }
      object.module_eval { @five = build }
      object.module_exec(argument) { @six = build }
    RUBY

    assert blocks.none? { |block|
      Helpers.self_preserved_between?(block.body, boundary: block.each_ancestor.first)
    }
  end

  test "self_preserved_between? accepts evaluation against the current self" do
    blocks = processed_source(<<~RUBY).ast.children
      instance_eval { @one = build }
      self.instance_exec(argument) { @two = build }
    RUBY

    assert blocks.all? { |block|
      Helpers.self_preserved_between?(block.body, boundary: block.each_ancestor.first)
    }
  end

  test "self_preserved_between? rejects block parameter defaults evaluated against the receiver" do
    block = processed_source("object.instance_exec { |value = (@value = build)| value }").ast
    assignment = block.arguments.each_descendant(:ivasgn).first

    assert_not Helpers.self_preserved_between?(assignment, boundary: block.each_ancestor.first)
  end

  test "self_preserved_between? rejects dynamically defined method bodies while preserving their arguments" do
    ast = processed_source(<<~RUBY).ast
      define_method(@name = method_name) { @dynamic = build }
      target.define_singleton_method(@singleton_name = other_name) { @singleton = build }
    RUBY

    preservation_by_name = ast.each_descendant(:ivasgn).to_h do |assignment|
      [ assignment.name, Helpers.self_preserved_between?(assignment, boundary: nil) ]
    end

    assert_equal({
      "@name": true, "@dynamic": false, "@singleton_name": true, "@singleton": false
    }, preservation_by_name)
  end

  test "self_preserved_between? rejects lexical bodies while preserving definition inputs" do
    ast = processed_source(<<~RUBY).ast
      def (@owner = target).run
        @defined = build
      end

      class Child < (@parent = parent)
        @class_state = build
      end
    RUBY

    preservation_by_name = ast.each_descendant(:ivasgn).to_h do |assignment|
      [ assignment.name, Helpers.self_preserved_between?(assignment, boundary: nil) ]
    end

    assert_equal({ "@owner": true, "@defined": false, "@parent": true, "@class_state": false }, preservation_by_name)
  end

  test "self_rebinding_boundary? recognizes definitions and blocks that evaluate with another self" do
    boundaries = processed_source(<<~RUBY).ast.children
      class Nested; end
      Class.new { build }
      target.instance_eval { build }
      define_method(:build) { work }
      items.each { work }
      self.instance_eval { work }
      Domain::Class.new { build }
    RUBY

    assert_equal [ true, true, true, true, false, false, false ],
      boundaries.map { Helpers.self_rebinding_boundary?(it) }
  end

  test "nested_body? returns true for a module carrying behavior" do
    node = processed_source("module Filters\n  def filter\n  end\nend").ast

    assert Helpers.nested_body?(node)
  end

  test "nested_body? returns true for a class carrying behavior" do
    node = processed_source("class Row\n  def name\n  end\nend").ast

    assert Helpers.nested_body?(node)
  end

  test "nested_body? returns false for an empty module" do
    node = processed_source("module Marker\nend").ast

    assert_not Helpers.nested_body?(node)
  end

  test "nested_body? returns true for a Module builder carrying behavior" do
    assert nested_body_of?("Marker = Module.new do\n  def marked? = true\nend")
  end

  test "class_with_body? returns true for a class holding methods" do
    node = processed_source("class Foo\n  def bar; end\nend").ast

    assert Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a class with no body" do
    node = processed_source("class Foo < Bar; end").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "class_with_body? returns true for a class builder taking a block" do
    assert class_with_body_of?("Entry = Data.define(:sku) do\n  def total; end\nend")
  end

  test "class_with_body? returns true for an explicitly top-level class builder" do
    assert class_with_body_of?("Entry = ::Data.define(:sku) do\n  def total; end\nend")
  end

  test "class_with_body? returns false for a namespaced class builder lookalike" do
    assert_not class_with_body_of?("Entry = Domain::Data.define(:sku) do\n  def total; end\nend")
  end

  test "class_with_body? returns false for a Module builder" do
    assert_not class_with_body_of?("Entry = Module.new do\n  def total; end\nend")
  end

  test "class_with_body? returns false for a class builder with no block" do
    assert_not class_with_body_of?("Entry = Data.define(:sku, :quantity)")
  end

  test "class_with_body? returns false for an empty or comment-only builder block" do
    assert_not class_with_body_of?("Entry = Data.define(:sku) {}")
    assert_not class_with_body_of?("Entry = Data.define(:sku) { # marker\n}")
  end

  test "class_with_body? returns false for a block on a constructor with no receiver" do
    node = processed_source("Entry = new do\n  def total; end\nend").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a block on a constructor another object answers" do
    node = processed_source("Entry = factory.new do\n  def total; end\nend").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "class_with_body? returns false for a constant that builds nothing" do
    node = processed_source("FORMATS = [ :json ]").ast

    assert_not Helpers.class_with_body?(node)
  end

  test "module_with_body? returns true only for core Module builders with a body" do
    assert module_with_body_of?("Entry = ::Module.new do\n  def total; end\nend")
    assert_not module_with_body_of?("Entry = Domain::Module.new do\n  def total; end\nend")
  end

  test "module_with_body? returns false for an empty or comment-only builder block" do
    assert_not module_with_body_of?("Entry = Module.new {}")
    assert_not module_with_body_of?("Entry = Module.new { # marker\n}")
  end

  private
    def nested_body_of?(source)
      Helpers.nested_body?(processed_source(source).ast)
    end

    def class_with_body_of?(source)
      Helpers.class_with_body?(processed_source(source).ast)
    end

    def module_with_body_of?(source)
      Helpers.module_with_body?(processed_source(source).ast)
    end
end
