require "test_helper"

class RuboCop::Callbacksystems::Methods::SiblingsTest < ActiveSupport::TestCase
  include SourceParsing

  test "named returns only direct methods in the same container and domain" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def run; end
        def target; end
        def self.target; end

        class Inner
          def target; end
        end
      end
    RUBY
    run = ast.each_descendant(:def).first

    definitions = RuboCop::Callbacksystems::Methods::Siblings.new.named(:target, beside: run)

    assert_equal [ "def target; end" ], definitions.map(&:source)
  end

  test "named finds definitions inside a singleton class" do
    ast = processed_source(<<~RUBY).ast
      class Example
        class << self
          def run; end
          def target; end
        end
      end
    RUBY
    run = ast.each_descendant(:def).first

    definitions = RuboCop::Callbacksystems::Methods::Siblings.new.named(:target, beside: run)

    assert_equal [ "def target; end" ], definitions.map(&:source)
  end

  test "named keeps second-order singleton definitions in their own domain" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def self.target; end

        class << self
          def run; end
          def self.target; end
          def self.second_order_run; end
        end
      end
    RUBY
    outer_target, run, inner_target, second_order_run = ast.each_descendant(:any_def).to_a
    methods = RuboCop::Callbacksystems::Methods::Siblings.new

    assert_same outer_target, methods.named(:target, beside: run).first
    assert_same inner_target, methods.named(:target, beside: second_order_run).first
  end

  test "named keeps definitions in singleton classes for different expressions separate" do
    ast = processed_source(<<~RUBY).ast
      class Example
        class << FIRST
          def run; end
          def target; end
        end

        class << SECOND
          def run; end
          def target; end
        end
      end
    RUBY
    first_run, _first_target, second_run, second_target = ast.each_descendant(:def).to_a
    methods = RuboCop::Callbacksystems::Methods::Siblings.new

    assert_same second_target, methods.named(:target, beside: second_run).first
    assert_not_same second_target, methods.named(:target, beside: first_run).first
  end

  test "named keeps definitions on another object outside the class self domain" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def self.run; end
        def OTHER.target; end
      end
    RUBY
    run = ast.each_descendant(:any_def).first

    assert_empty RuboCop::Callbacksystems::Methods::Siblings.new.named(:target, beside: run)
  end

  test "named finds sibling methods inside the same anonymous class block" do
    ast = processed_source(<<~RUBY).ast
      class Example
        Handler = Class.new do
          def run; end
          def target; end
        end
      end
    RUBY
    run, target = ast.each_descendant(:def).to_a

    assert_same target, RuboCop::Callbacksystems::Methods::Siblings.new.named(:target, beside: run).first
  end

  test "named keeps methods in separate anonymous class blocks isolated" do
    ast = processed_source(<<~RUBY).ast
      class Example
        First = Class.new do
          def run; end
          def target; end
        end

        Second = Class.new do
          def run; end
          def target; end
        end
      end
    RUBY
    first_run, _first_target, second_run, second_target = ast.each_descendant(:def).to_a
    methods = RuboCop::Callbacksystems::Methods::Siblings.new

    assert_same second_target, methods.named(:target, beside: second_run).first
    assert_not_same second_target, methods.named(:target, beside: first_run).first
  end

  test "named keeps structurally identical containers separate" do
    ast = processed_source(<<~RUBY).ast
      class Example
        def run; end
        def target; end
      end
      class Example
        def run; end
        def target; end
      end
    RUBY
    first_run, _first_target, second_run, second_target = ast.each_descendant(:def).to_a
    index = RuboCop::Callbacksystems::Methods::Siblings.new
    index.named(:target, beside: first_run)

    assert_same second_target, index.named(:target, beside: second_run).first
  end

  test "named returns nothing beside a top-level method" do
    method = processed_source("def run; end\n").ast

    assert_empty RuboCop::Callbacksystems::Methods::Siblings.new.named(:run, beside: method)
  end
end
