require "test_helper"

class RuboCop::Callbacksystems::Methods::DefinitionsTest < ActiveSupport::TestCase
  include SourceParsing

  test "each yields nothing for a class with no body" do
    assert_empty method_names("class User\nend\n")
  end

  test "each yields nothing when there is no code at all" do
    assert_empty method_names("")
  end

  test "definition traversal returns an enumerator without a block" do
    ast = processed_source("class User\n  def name; end\nend\n").ast
    body = RuboCop::Callbacksystems::Methods::Definitions::Body.new(ast.body, depth: 0, context: :owner)
    traversal = RuboCop::Callbacksystems::Methods::Definitions::Traversal.new([ body ])

    assert_instance_of Enumerator, traversal.each
    assert_equal [ :name ], traversal.each.map(&:name)
  end

  test "each yields the methods of every class the file defines" do
    assert_equal [ :name, :title ], method_names(<<~RUBY)
      class User
        def name
        end
      end

      class Post
        def title
        end
      end
    RUBY
  end

  test "each skips a scope that names nothing" do
    assert_empty method_names(<<~RUBY)
      class Article
        scope
      end
    RUBY
  end

  test "each skips a scope whose first argument is not a symbol" do
    assert_empty method_names(<<~RUBY)
      class Article
        scope "published", -> { where(published: true) }
      end
    RUBY
  end

  test "each yields public method names" do
    assert_equal %i[ name email ], method_names(<<~RUBY)
      class User
        def name; end
        def email; end
      end
    RUBY
  end

  test "each skips private methods" do
    assert_equal %i[ name ], method_names(<<~RUBY)
      class User
        def name; end

        private
          def secret; end
      end
    RUBY
  end

  test "each yields the methods below a public modifier reopening the section" do
    assert_equal %i[ b ], method_names(<<~RUBY)
      class User
        private
          def a; end

        public
          def b; end
      end
    RUBY
  end

  test "each yields scopes" do
    assert_equal %i[ published name ], method_names(<<~RUBY)
      class Article
        scope :published, -> { where(published: true) }
        def name; end
      end
    RUBY
  end

  test "each yields methods from a class_methods block" do
    assert_equal %i[ build_with_listing some_method ], method_names(<<~RUBY)
      module Publishable
        extend ActiveSupport::Concern

        class_methods do
          def build_with_listing(attributes)
          end
        end

        def some_method
        end
      end
    RUBY
  end

  test "each yields methods from class << self" do
    assert_equal %i[ sync retrieve name ], method_names(<<~RUBY)
      class Charge
        class << self
          def sync; end
          def retrieve; end
        end

        def name; end
      end
    RUBY
  end

  test "each yields def self.method_name" do
    assert_equal %i[ find_by_email name ], method_names(<<~RUBY)
      class User
        def self.find_by_email(email); end
        def name; end
      end
    RUBY
  end

  test "each skips methods from nested classes" do
    assert_equal %i[ process ], method_names(<<~RUBY)
      class Outer
        def process; end

        private
          class Inner
            def helper; end
          end
      end
    RUBY
  end

  test "each yields methods from an included block" do
    assert_equal %i[ setup_method instance_method ], method_names(<<~RUBY)
      module Concern
        included do
          def setup_method; end
        end

        def instance_method; end
      end
    RUBY
  end

  test "each yields methods from a prepended block" do
    assert_equal %i[ wrapper instance_method ], method_names(<<~RUBY)
      module Decoration
        prepended do
          def wrapper; end
        end

        def instance_method; end
      end
    RUBY
  end

  test "each skips definitions that belong to another singleton object" do
    assert_equal %i[ own ], method_names(<<~RUBY)
      class Report
        def self.own; end
        def OTHER.foreign; end

        class << OTHER
          def foreign_section; end
        end
      end
    RUBY
  end

  test "each skips definitions on the singleton class's singleton class" do
    assert_equal %i[ direct first_order ], method_names(<<~RUBY)
      class Report
        def self.direct; end

        class << self
          def first_order; end
          def self.second_order; end

          class << self
            def also_second_order; end
          end
        end
      end
    RUBY
  end

  test "each skips singleton definitions inside a class_methods block" do
    assert_equal %i[ build ], method_names(<<~RUBY)
      module Factory
        class_methods do
          def build; end
          def self.metadata; end

          class << self
            def other_metadata; end
          end
        end
      end
    RUBY
  end

  test "each skips definition blocks entered from a singleton section" do
    assert_empty method_names(<<~RUBY)
      class Report
        class << self
          included do
            def foreign; end
          end
        end
      end
    RUBY
  end

  test "each uses the final visibility assigned to a method" do
    assert_equal %i[ reopened ], method_names(<<~RUBY)
      class Report
        def hidden; work; end
        private :hidden

        private def reopened; work; end
        public :reopened
      end
    RUBY
  end

  test "each respects wrapped visibility and class method modifiers" do
    assert_equal %i[ exposed class_side reopened_class_side ], method_names(<<~RUBY)
      class Report
        def self.hidden_class_side; work; end
        private_class_method :hidden_class_side

        private
          public def exposed; work; end
          def self.class_side; work; end
          private_class_method def self.also_hidden_class_side; work; end
          public_class_method def self.reopened_class_side; work; end
      end
    RUBY
  end

  test "each reads outer visibility assignments for a singleton section" do
    assert_equal %i[ shown ], method_names(<<~RUBY)
      class Report
        class << self
          def hidden; work; end

          private
            def shown; work; end
        end

        private_class_method :hidden
        public_class_method :shown
      end
    RUBY
  end

  test "each yields a block scope even below a private instance section" do
    assert_equal %i[ active ], method_names(<<~RUBY)
      class Report
        private
          scope :active do
            all
          end
      end
    RUBY
  end

  test "each skips definitions inside a block whose method ownership is unknown" do
    assert_equal %i[ own ], method_names(<<~RUBY)
      class Report
        configure do
          def foreign; end
        end

        OTHER.class_methods do
          def other_foreign; end
        end

        def own; end
      end
    RUBY
  end

  test "each walks nested definition bodies deeper than Ruby's call stack" do
    definition = RuboCop::AST::DefNode.new(:def, [ :work, RuboCop::AST::Node.new(:args), nil ])
    body = 5_000.times.reduce(definition) do |nested, _|
      call = RuboCop::AST::SendNode.new(:send, [ nil, :class_methods ])
      RuboCop::AST::BlockNode.new(:block, [ call, RuboCop::AST::Node.new(:args), nested ])
    end
    identifier = RuboCop::AST::Node.new(:const, [ nil, :Container ])
    container = RuboCop::AST::ClassNode.new(:class, [ identifier, nil, body ])

    assert_equal [ :work ], RuboCop::Callbacksystems::Methods::Definitions.new(container).map(&:name)
  end

  private
    def method_names(source)
      processed = processed_source(source)
      RuboCop::Callbacksystems::Methods::Definitions.new(processed.ast).map(&:name)
    end
end
