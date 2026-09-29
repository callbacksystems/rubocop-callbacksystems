module RuboCop::Callbacksystems::Source::FileAst
  extend self

  def ast(path, ruby_version:)
    processed_source(path, ruby_version:)&.ast
  end

  def processed_source(path, ruby_version:)
    return unless path && File.exist?(path)

    RuboCop::AST::ProcessedSource.new(File.read(path), ruby_version, path)
  rescue SystemCallError, EncodingError
    nil
  end
end
