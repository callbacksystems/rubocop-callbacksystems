require "test_helper"
require "fileutils"

class RuboCop::Callbacksystems::FileAstTest < ActiveSupport::TestCase
  test "ast returns the AST of an existing file" do
    Dir.mktmpdir do |dir|
      path = "#{dir}/example.rb"
      File.write(path, "class Foo; end")

      ast = RuboCop::Callbacksystems::FileAst.ast(path)

      assert_equal :class, ast.type
    end
  end

  test "ast returns nil for a missing file" do
    assert_nil RuboCop::Callbacksystems::FileAst.ast("/tmp/definitely-missing-file-#{rand(1_000_000)}.rb")
  end

  test "ast returns nil for nil path" do
    assert_nil RuboCop::Callbacksystems::FileAst.ast(nil)
  end

  test "ast returns nil when parsing raises" do
    Dir.mktmpdir do |dir|
      path = "#{dir}/broken.rb"
      File.write(path, "this is not valid \xFF ruby")

      assert_nothing_raised do
        RuboCop::Callbacksystems::FileAst.ast(path)
      end
    end
  end
end
