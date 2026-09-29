require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::CoverageTest < ActiveSupport::TestCase
  include TemporaryProject

  test "register supplements a Ruby document omitted by index_all" do
    path = create_file("Gemfile", "class GemfileDeclaration; end\n")
    index = raw_index_for(path)

    assert_nil index["GemfileDeclaration"]

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths: [ path ])

    assert_predicate index["GemfileDeclaration"], :itself
    assert RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  test "register transcodes an external ISO-8859-1 document" do
    source = "# encoding: ISO-8859-1\nclass Legacy; VALUE = \"caf\xE9\"; end\n".b
    path = create_file("lib/legacy.rb", source)
    index = raw_index_for(path)

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths: [ path ])

    assert_predicate index["Legacy"], :itself
    assert RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  test "register recognizes the canonical identity behind a symlink" do
    target = create_file("lib/example.rb", "class Example; end\n")
    link = project.path_of("lib/example_link.rb")
    File.symlink(target, link)
    index = raw_index_for(target)

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths: [ link ])

    assert RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
    assert_equal 1, index.documents.count { it.uri.start_with?("file://") }
  end

  test "register reads an already complete document set once" do
    path = create_file("lib/example.rb", "class Example; end\n")
    index = IndexWithCountedDocuments.new(raw_index_for(path))

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths: [ path ])

    assert_equal 1, index.document_read_count
    assert RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  test "register marks the graph incomplete when coverage cannot be built" do
    index = Object.new
    paths = Object.new
    paths.define_singleton_method(:to_set) { |*| raise "coverage failure" }

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths:)

    assert_not RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  test "complete? rejects a document that cannot be transcoded" do
    source = "# encoding: ASCII-8BIT\nVALUE = \"\xFF\"\n".b
    path = create_file("lib/binary.rb", source)
    index = raw_index_for(path)

    RuboCop::Callbacksystems::ProjectIndex::Coverage.register(index, paths: [ path ])

    assert_not RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
    assert_empty index.documents.select { it.uri.start_with?("file://") }
  end

  test "complete? rejects an unregistered graph" do
    index = raw_index_for(create_file("lib/example.rb", "class Example; end\n"))

    assert_not RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  private
    def raw_index_for(*paths)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      Rubydex::Graph.new.tap do |index|
        index.index_all(paths)
        index.resolve
      end
    end

    class IndexWithCountedDocuments
      attr_reader :document_read_count

      def initialize(index)
        @index = index
        @document_read_count = 0
      end

      def documents
        @document_read_count += 1
        index.documents
      end

      private
        attr_reader :index
    end
end
