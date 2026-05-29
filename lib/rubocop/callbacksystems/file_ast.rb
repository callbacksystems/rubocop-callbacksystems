module RuboCop::Callbacksystems::FileAst
  extend self

  def ast(path)
    return unless path && File.exist?(path)

    RuboCop::AST::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f, path).ast
  rescue
    nil
  end
end
