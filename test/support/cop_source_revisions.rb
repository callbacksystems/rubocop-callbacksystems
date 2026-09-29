class CopSourceRevisions
  def initialize(cop_class, file:, project_index:)
    @cop = cop_class.new(nil, autocorrect: true).tap { it.project_index = project_index }
    @processed_source = RuboCop::ProcessedSource.from_file(file, RUBY_VERSION.to_f)
  end

  def offense_count
    commissioner.investigate(processed_source).offenses.size
  end

  def update(source)
    if RuboCop::Callbacksystems::ProjectIndex::Freshness.update(cop.project_index, processed_source, source)
      @processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, processed_source.file_path)
    else
      raise "Expected the indexed source revision to be accepted"
    end
  end

  private
    attr_reader :cop, :processed_source

    def commissioner
      @commissioner ||= RuboCop::Cop::Commissioner.new([ cop ], [], raise_error: true)
    end
end
