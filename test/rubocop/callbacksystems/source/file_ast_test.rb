require "test_helper"

class RuboCop::Callbacksystems::Source::FileAstTest < ActiveSupport::TestCase
  include TemporaryProject

  test "ast returns the AST of an existing file" do
    ast = RuboCop::Callbacksystems::Source::FileAst.ast \
      create_file("example.rb", "class Foo; end"), ruby_version: RUBY_VERSION.to_f

    assert_equal :class, ast.type
  end

  test "ast returns nil for a missing file" do
    assert_nil RuboCop::Callbacksystems::Source::FileAst.ast \
      "/tmp/definitely-missing-file-#{rand(1_000_000)}.rb", ruby_version: RUBY_VERSION.to_f
  end

  test "ast returns nil for nil path" do
    assert_nil RuboCop::Callbacksystems::Source::FileAst.ast(nil, ruby_version: RUBY_VERSION.to_f)
  end

  test "ast returns nil when parsing raises" do
    path = create_file("broken.rb", "this is not valid \xFF ruby")

    assert_nothing_raised do
      RuboCop::Callbacksystems::Source::FileAst.ast(path, ruby_version: RUBY_VERSION.to_f)
    end
  end

  test "processed_source returns nil when the existing path cannot be read as a file" do
    assert_nil RuboCop::Callbacksystems::Source::FileAst.processed_source(project.path, ruby_version: RUBY_VERSION.to_f)
  end

  test "processed_source preserves syntax validity when a file has no AST" do
    empty_source = RuboCop::Callbacksystems::Source::FileAst.processed_source \
      create_file("empty.rb"), ruby_version: RUBY_VERSION.to_f
    invalid_source = RuboCop::Callbacksystems::Source::FileAst.processed_source \
      create_file("invalid.rb", "class Broken <\n"), ruby_version: RUBY_VERSION.to_f

    assert_predicate empty_source, :valid_syntax?
    assert_not_predicate invalid_source, :valid_syntax?
  end

  test "processed_source does not hide an invalid parser version" do
    path = create_file("example.rb", "class Example; end")

    assert_raises(NoMethodError) do
      RuboCop::Callbacksystems::Source::FileAst.processed_source(path, ruby_version: Object.new)
    end
  end
end
