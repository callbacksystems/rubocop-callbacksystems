require "test_helper"

class RuboCop::Callbacksystems::Execution::ImmediateTest < ActiveSupport::TestCase
  include SourceParsing

  test "nodes_of_type includes calls in ordinary nested blocks" do
    execution = immediate_execution("wrapper { post users_url }")

    assert_equal %i[ wrapper post users_url ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type excludes lexical definition bodies but includes inputs evaluated while they open" do
    execution = immediate_execution <<~RUBY
      begin
        def instance_method
          get users_url
        end
        def object.singleton_method
          post users_url
        end
        class Nested < parent_class
          put users_url
        end
        module Helpers
          patch users_url
        end
        class << object
          delete users_url
        end
      end
    RUBY

    assert_equal %i[ object parent_class object ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type excludes calls inside deferred callables" do
    execution = immediate_execution <<~RUBY
      begin
        -> { get users_url }
        lambda { post users_url }
        proc { put users_url }
        Proc.new { patch users_url }
      end
    RUBY

    assert_empty execution.nodes_of_type(:send)
  end

  test "nodes_of_type excludes calls inside dynamically defined methods" do
    execution = immediate_execution <<~RUBY
      begin
        define_method(:read) { get users_url }
        object.define_singleton_method(:write) { post users_url }
      end
    RUBY

    assert_equal [ :object ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type includes arguments evaluated when a deferred callable is built" do
    execution = immediate_execution <<~RUBY
      proc(object.send(:callable_name)) { deferred.send(:later) }
    RUBY

    assert_equal %i[ send object ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type accepts additional deferred blocks without entering their bodies" do
    source = processed_source("install(object.send(:method_name)) { deferred.send(:later) }")
    execution = RuboCop::Callbacksystems::Execution::Immediate.new(source.ast, deferred_blocks: [ source.ast ])

    assert_equal %i[ send object ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type does not confuse namespaced callable lookalikes with core callables" do
    execution = immediate_execution <<~RUBY
      begin
        Foo::Kernel.lambda { get users_url }
        Foo::Proc.new { post users_url }
      end
    RUBY

    assert_equal %i[ lambda get users_url new post users_url ], execution.nodes_of_type(:send).map(&:method_name)
  end

  test "nodes_of_type is empty without a tree" do
    assert_empty RuboCop::Callbacksystems::Execution::Immediate.new(nil).nodes_of_type(:send)
  end

  test "each returns an enumerator that yields the immediate nodes in source order" do
    execution = immediate_execution("wrapper { work }")

    assert_equal %w[ wrapper work ], execution.each.select(&:send_type?).map { it.method_name.to_s }
  end

  private
    def immediate_execution(source)
      RuboCop::Callbacksystems::Execution::Immediate.new(processed_source(source).ast)
    end
end
