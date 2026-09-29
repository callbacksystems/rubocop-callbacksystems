require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::SourceFileTest < ActiveSupport::TestCase
  include TemporaryProject

  test "for_document decodes an escaped file URI" do
    path = create_file("lib/café space.rb", "class Example; end\n")
    document = Document.new("file://#{URI::DEFAULT_PARSER.escape(path)}")
    flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

    source_file = RuboCop::Callbacksystems::ProjectIndex::SourceFile.for_document(document)

    assert_equal File.realpath(path), source_file.path
  end

  test "eql? recognizes the same file through a symlink" do
    path = create_file("lib/example.rb", "class Example; end\n")
    link = project.path_of("lib/example_link.rb")
    File.symlink(path, link)
    source_file = RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(path)

    assert source_file.eql?(RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(link))
    assert_not source_file.eql?(Object.new)
  end

  test "source rejects source that remains invalid after transcoding" do
    source = "# encoding: UTF-8\nVALUE = \"\xFF\"\n".b
    path = create_file("lib/invalid.rb", source)
    source_file = RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(path)

    assert_raises(EncodingError) { source_file.source }
  end

  test "uri normalizes Windows identity and URI paths" do
    source_file = RuboCop::Callbacksystems::ProjectIndex::SourceFile.allocate
    source_file.instance_variable_set(:@path, "C:\\Repo\\Example.rb")
    source_file.instance_variable_set(:@windows, true)

    assert_equal "c:/repo/example.rb".hash, source_file.hash
    assert_equal "file:///C:/Repo/Example.rb", source_file.uri
  end

  private
    Document = Data.define(:uri)
end
