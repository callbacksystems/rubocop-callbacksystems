require "test_helper"

class RuboCop::Callbacksystems::HelpersTest < ActiveSupport::TestCase
  Helpers = RuboCop::Callbacksystems::Helpers

  test "const_added wires a newly added submodule into Helpers" do
    submodule = Module.new do
      def dynamic_added_helper
        :wired
      end
    end
    Helpers.const_set(:DynamicAddedHelper, submodule)

    assert_respond_to Helpers, :dynamic_added_helper
    assert_equal :wired, Helpers.dynamic_added_helper
  ensure
    remove_helper_constant(:DynamicAddedHelper)
  end

  test "const_added gives the new submodule access to other helpers' methods" do
    submodule = Module.new do
      extend self

      def parsed_constant_name
        constant_name_of(ast("Foo"))
      end

      def ast(source)
        RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
      end
    end
    Helpers.const_set(:CrossHelperAccess, submodule)

    assert_equal "Foo", submodule.parsed_constant_name
  ensure
    remove_helper_constant(:CrossHelperAccess)
  end

  test "const_added skips non-module constants" do
    Helpers.const_set(:SomeNumberConstant, 42)

    assert_equal 42, Helpers::SomeNumberConstant
  ensure
    remove_helper_constant(:SomeNumberConstant)
  end

  private
    def remove_helper_constant(name)
      Helpers.module_eval { remove_const(name) } if Helpers.const_defined?(name, false)
    end
end
