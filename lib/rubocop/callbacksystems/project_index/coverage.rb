class RuboCop::Callbacksystems::ProjectIndex::Coverage
  class << self
    def register(project_index, paths:)
      self.cached = [ project_index, new(project_index, paths:) ]
    rescue
      self.cached = [ project_index, nil ]
    end

    def complete?(project_index)
      cached.then do |index, coverage|
        coverage ? index.equal?(project_index) && coverage.complete? : false
      end
    end

    private
      attr_accessor :cached
  end

  def initialize(project_index, paths:)
    @project_index = project_index
    @expected_files = paths.to_set { RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(it) }
    @complete = missing_files.empty? || (supplemented? && indexed_files == expected_files)
  end

  def complete?
    complete
  end

  private
    attr_reader :project_index, :expected_files, :complete

    def missing_files
      @missing_files ||= expected_files - indexed_files
    end

    def indexed_files
      project_index.documents.filter_map do |document|
        if document.uri.start_with?(RuboCop::Cop::ProjectIndexHelp::FILE_URI_PREFIX)
          RuboCop::Callbacksystems::ProjectIndex::SourceFile.for_document(document)
        end
      end.to_set
    end

    def supplemented?
      missing_files.map { index_file(it) }.all?.tap { project_index.resolve }
    rescue
      false
    end

    def index_file(file)
      project_index.index_source(file.uri, file.source, "ruby")
      true
    rescue
      false
    end
end
