require "uri"

class RuboCop::Callbacksystems::ProjectIndex::SourceFile
  attr_reader :path

  delegate :hash, to: :identity

  class << self
    def for_document(document)
      Rubydex::Location.new(uri: document.uri, start_line: 0, start_column: 0, end_line: 0, end_column: 0)
        .then { new(it.to_file_path) }
    end
  end

  def initialize(path)
    @path = canonical_path_of(path.to_s)
    @windows = Gem.win_platform?
  end

  def eql?(other)
    other.is_a?(self.class) && identity == other.identity
  end

  def source
    Parser::Source::Buffer.new(path).read.source.encode(Encoding::UTF_8).tap do |source|
      raise EncodingError, "Cannot index invalid UTF-8 source: #{path}" unless source.valid_encoding?
    end
  end

  def uri
    "file://#{URI::DEFAULT_PARSER.escape(uri_path)}"
  end

  protected
    def identity
      @identity ||= normalized_path.then { windows ? it.downcase : it }
    end

  private
    attr_reader :windows

    def canonical_path_of(path)
      File.realpath(path)
    rescue SystemCallError
      File.expand_path(path)
    end

    def normalized_path
      @normalized_path ||= path.tr("\\", "/")
    end

    def uri_path
      if windows && !normalized_path.start_with?("/")
        "/#{normalized_path}"
      else
        normalized_path
      end
    end
end
