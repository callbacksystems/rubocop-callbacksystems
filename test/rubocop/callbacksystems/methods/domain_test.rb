require "test_helper"

class RuboCop::Callbacksystems::Methods::DomainTest < ActiveSupport::TestCase
  include SourceParsing

  test "container returns the nearest class or module" do
    method = method_named("class Outer; class Inner; def run; end; end; end\n", :run)

    assert_equal :Inner, RuboCop::Callbacksystems::Methods::Domain.new(method).container.identifier.short_name
  end

  test "container returns the runtime block around an anonymous class method" do
    source = processed_source("class Outer; Handler = Class.new do; def run; end; end; end\n")
    block = source.ast.each_descendant(:any_block).first
    method = source.ast.each_descendant(:def).first

    assert_same block, RuboCop::Callbacksystems::Methods::Domain.new(method).container
  end

  test "scope returns instance for an ordinary definition" do
    method = method_named("class Example; def run; end; end\n", :run)

    assert_equal :instance, RuboCop::Callbacksystems::Methods::Domain.new(method).scope
  end

  test "scope returns singleton for a defs definition" do
    method = processed_source("class Example; def self.run; end; end\n").ast.body

    assert_equal :singleton, RuboCop::Callbacksystems::Methods::Domain.new(method).scope
  end

  test "scope returns singleton for a definition directly inside a singleton class" do
    method = method_named("class Example; class << self; def run; end; end; end\n", :run)

    assert_equal :singleton, RuboCop::Callbacksystems::Methods::Domain.new(method).scope
  end

  test "scope returns instance for a nested class definition inside a singleton class" do
    method = method_named("class << self; class Inner; def run; end; end; end\n", :run)

    assert_equal :instance, RuboCop::Callbacksystems::Methods::Domain.new(method).scope
  end

  test "scope returns singleton for a receiverless call in a class body" do
    call = processed_source("class Example; configure; end\n").ast.body

    assert_equal :singleton, RuboCop::Callbacksystems::Methods::Domain.new(call).scope
  end

  test "scope follows the method surrounding a call" do
    calls = processed_source("class Example; def run; target; end; def self.build; target; end; end\n")
      .ast.each_descendant(:send).to_a

    assert_equal %i[ instance singleton ], calls.map { RuboCop::Callbacksystems::Methods::Domain.new(it).scope }
  end

  test "singleton? tells whether the node belongs to the singleton side" do
    method = processed_source("def self.run; end\n").ast

    assert RuboCop::Callbacksystems::Methods::Domain.new(method).singleton?
  end

  test "singleton_depth distinguishes an explicit singleton definition inside a singleton class" do
    methods = processed_source(<<~RUBY).ast.each_descendant(:any_def).to_a
      class Example
        def self.first_order; end

        class << self
          def first_order_too; end
          def self.second_order; end
        end
      end
    RUBY

    assert_equal [ 1, 1, 2 ], methods.map { RuboCop::Callbacksystems::Methods::Domain.new(it).singleton_depth }
  end

  test "identity distinguishes singleton classes opened on different expressions" do
    methods = processed_source(<<~RUBY).ast.each_descendant(:def).to_a
      class Example
        class << FIRST
          def run; end
        end

        class << SECOND
          def run; end
        end
      end
    RUBY

    identities = methods.map { RuboCop::Callbacksystems::Methods::Domain.new(it).identity }

    assert_not_equal identities.first, identities.last
  end

  test "identity unifies explicit singleton definitions with definitions inside class self" do
    methods = processed_source(<<~RUBY).ast.each_descendant(:any_def).to_a
      class Example
        def self.first; end

        class << self
          def second; end
        end
      end
    RUBY

    identities = methods.map { RuboCop::Callbacksystems::Methods::Domain.new(it).identity }

    assert_equal identities.first, identities.last
  end

  test "identity keeps a definition on another object outside the class self domain" do
    methods = processed_source(<<~RUBY).ast.each_descendant(:any_def).to_a
      class Example
        def self.first; end
        def OTHER.second; end
      end
    RUBY

    identities = methods.map { RuboCop::Callbacksystems::Methods::Domain.new(it).identity }

    assert_not_equal identities.first, identities.last
  end

  test "identity gives calls in a definition on another object that definition's domain" do
    method = processed_source("class Example; def OTHER.run; target; end; end\n").ast.body
    call = method.body

    assert_equal RuboCop::Callbacksystems::Methods::Domain.new(method).identity,
      RuboCop::Callbacksystems::Methods::Domain.new(call).identity
  end
end
