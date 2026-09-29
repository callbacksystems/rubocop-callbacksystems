require "test_helper"

class RuboCop::Callbacksystems::Execution::LocalVariableOccurrencesTest < ActiveSupport::TestCase
  include SourceParsing

  test "named returns the assignments and reads carrying the name in the surrounding scope" do
    ast = processed_source("def run\n  value = build\n  use(value)\nend\n").ast
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named(:value, around: assignment)

    assert_equal %i[ lvasgn lvar ], occurrences.map(&:type)
  end

  test "named leaves occurrences from a sibling scope out" do
    ast = processed_source("def one\n  value = first\nend\ndef two\n  value = second\nend\n").ast
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named(:value, around: assignment)

    assert_equal [ "value = first" ], occurrences.map(&:source)
  end

  test "named keeps structurally identical sibling scopes separate" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        use(value)
      end
      def run
        value = build
        use(value)
      end
    RUBY
    first, second = ast.each_descendant(:lvasgn).to_a
    index = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
    index.named(:value, around: first)

    occurrences = index.named(:value, around: second)

    assert_same second, occurrences.first
  end

  test "named returns nothing when the surrounding scope does not carry the name" do
    ast = processed_source("def run\n  value = build\nend\n").ast
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named(:other, around: assignment)

    assert_empty occurrences
  end

  test "named excludes occurrences inside a nested method and class" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build

        Class.new do
          def nested
            value = other
          end
        end

        use(value)
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named(:value, around: assignment)

    assert_equal [ "value = build", "value" ], occurrences.map(&:source)
  end

  test "named includes pattern bindings in the lexical scope" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        input => { value: }
        use(value)
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named(:value, around: assignment)

    assert_equal %i[ lvasgn match_var lvar ], occurrences.map(&:type)
  end

  test "named includes reads evaluated while lexical definitions are opened" do
    ast = processed_source(<<~RUBY).ast
      target = generated_target
      def target.run; end
      class << target; end

      superclass = generated_superclass
      class Child < superclass; end
    RUBY
    target, superclass = ast.each_descendant(:lvasgn).to_a
    index = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)

    target_occurrences = index.named(:target, around: target)
    superclass_occurrences = index.named(:superclass, around: superclass)

    assert_equal %i[ lvasgn lvar lvar ], target_occurrences.map(&:type)
    assert_equal %i[ lvasgn lvar ], superclass_occurrences.map(&:type)
  end

  test "named_in_method returns nothing outside a method" do
    ast = processed_source("value = build\n").ast

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: ast)

    assert_empty occurrences
  end

  test "named_in_method shares the method index with reads inside a block" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        items.each { use(value) }
      end
    RUBY
    read = ast.each_descendant(:lvar).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: read)

    assert_equal %i[ lvasgn lvar ], occurrences.map(&:type)
  end

  test "named_in_method excludes a value shadowed by a block parameter" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        items.each { |value| use(value) }
        use(value)
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: assignment)

    assert_equal [ "value = build", "value" ], occurrences.map(&:source)
  end

  test "named_in_method excludes occurrences inside a lambda" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        callback = -> { use(value) }
        use(value)
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: assignment)

    assert_equal [ "value = build", "value" ], occurrences.map(&:source)
  end

  test "named_in_method excludes occurrences inside Proc and dynamically defined method bodies" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        callback = proc { use(value) }
        other = Proc.new { use(value) }
        define_method(:later) { use(value) }
        use(value)
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: assignment)

    assert_equal [ "value = build", "value" ], occurrences.map(&:source)
  end

  test "named_in_method includes arguments evaluated before a dynamically defined method body" do
    ast = processed_source(<<~RUBY).ast
      def run
        value = build
        define_method(name_for(value)) { use(value) }
      end
    RUBY
    assignment = ast.each_descendant(:lvasgn).first

    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      .named_in_method(:value, around: assignment)

    assert_equal [ "value = build", "value" ], occurrences.map(&:source)
    assert_equal [ 2, 3 ], occurrences.map(&:first_line)
  end

  test "occurrences within return an enumerator without a block" do
    scope = processed_source("def run; value = build; use(value); end").ast
    occurrences = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences::OccurrencesWithin.new(scope)

    assert_instance_of Enumerator, occurrences.each
    assert_equal %i[ lvasgn lvar ], occurrences.each.map(&:type)
  end
end
