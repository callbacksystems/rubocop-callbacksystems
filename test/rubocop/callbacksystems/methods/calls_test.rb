require "test_helper"

class RuboCop::Callbacksystems::Methods::CallsTest < ActiveSupport::TestCase
  include SourceParsing

  test "named returns calls in the definition's class and method domain" do
    ast = processed_source(<<~RUBY).ast
      class First
        target

        def run
          target
        end

        def self.run
          target
        end
      end

      class Second
        def run
          target
        end
      end
    RUBY
    instance_method, singleton_method, other_method = ast.each_descendant(:any_def).to_a
    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast)

    assert_equal [ "target" ], calls.named(:target, from: instance_method).map(&:source)
    assert_equal [ "target", "target" ], calls.named(:target, from: singleton_method).map(&:source)
    assert_equal [ "target" ], calls.named(:target, from: other_method).map(&:source)
  end

  test "named returns implicit, explicit, and safely navigated calls on self" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def run
          target
          self.target
          self&.target
          other.target
        end
      end
    RUBY
    definition = ast.each_descendant(:def).first

    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast).named(:target, from: definition)

    assert_equal [ "target", "self.target", "self&.target" ], calls.map(&:source)
  end

  test "named keeps structurally identical classes separate" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def run
          target
        end
      end
      class Example
        def run
          target
        end
      end
    RUBY
    first, second = ast.each_descendant(:def).to_a
    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast)
    calls.named(:target, from: first)

    assert_same second.each_descendant(:send).first, calls.named(:target, from: second).first
  end

  test "named keeps second-order singleton calls in their own domain" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def self.outer
          target
        end

        class << self
          def inner
            target
          end

          def self.second_order
            target
          end
        end
      end
    RUBY
    outer, inner, second_order = ast.each_descendant(:any_def).to_a
    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast)

    assert_equal 2, calls.named(:target, from: outer).size
    assert_equal 2, calls.named(:target, from: inner).size
    assert_equal 1, calls.named(:target, from: second_order).size
  end

  test "named keeps calls in singleton classes for different expressions separate" do
    ast = processed_source(<<~RUBY).ast
      class Example
        class << FIRST
          def run
            target
          end
        end

        class << SECOND
          def run
            target
          end
        end
      end
    RUBY
    first, second = ast.each_descendant(:def).to_a
    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast)

    assert_equal [ first.each_descendant(:send).first ], calls.named(:target, from: first)
    assert_equal [ second.each_descendant(:send).first ], calls.named(:target, from: second)
  end

  test "named returns nothing for an unknown name" do
    ast = processed_source("def run; target; end\n").ast

    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast).named(:other, from: ast)

    assert_empty calls
  end

  test "named returns nothing when the definition's container has no calls" do
    ast = processed_source("class Example\n  def run; 1; end\nend\n").ast
    definition = ast.each_descendant(:def).first

    calls = RuboCop::Callbacksystems::Methods::Calls.new(ast).named(:target, from: definition)

    assert_empty calls
  end
end
