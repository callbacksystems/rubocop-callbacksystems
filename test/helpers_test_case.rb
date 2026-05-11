require "test_helper"

class HelpersTestCase < ActiveSupport::TestCase
  Helpers = RuboCop::Callbacksystems::Helpers

  private
    def parse(source)
      RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
    end

    def parse_method_body(source)
      parse(source).ast.then { it.def_type? ? it.body : it.each_node(:def).first.body }
    end

    def parse_class_body(source)
      parse(source).ast.body
    end

    def find_method(source, name)
      parse(source).ast.each_node(:def).find { it.method?(name) }
    end
end
