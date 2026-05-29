require "test_helper"

class HelpersTestCase < ActiveSupport::TestCase
  Helpers = RuboCop::Callbacksystems::Helpers

  private
    def processed_source(source)
      RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    end

    def method_body(source)
      processed_source(source).ast.then { it.def_type? ? it.body : it.each_node(:def).first.body }
    end

    def class_body(source)
      processed_source(source).ast.body
    end

    def method_named(source, name)
      processed_source(source).ast.each_node(:def).find { it.method?(name) }
    end
end
