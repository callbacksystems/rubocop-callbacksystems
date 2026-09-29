require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::FreshnessTest < ActiveSupport::TestCase
  include TemporaryProject

  test "update replaces a trusted disk document and records its in-memory revision" do
    path = create_file("lib/example.rb", "class Before; end\n")
    index = project_index_for(path)
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    corrected = "class After; end\n"

    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, corrected)
    assert_nil index["Before"]
    assert_predicate index["After"], :itself
  end

  test "update follows a chain of revisions while RuboCop defers its write" do
    path = create_file("lib/example.rb", "class First; end\n")
    index = project_index_for(path)
    first = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    second = RuboCop::ProcessedSource.new("class Second; end\n", RUBY_VERSION.to_f, path)

    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, first, second.raw_source)
    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, second, "class Third; end\n")
    assert_predicate index["Third"], :itself
  end

  test "update rejects an unsaved source that did not descend from the indexed file" do
    path = create_file("lib/example.rb", "class OnDisk; end\n")
    index = project_index_for(path)
    unsaved = RuboCop::ProcessedSource.new("class Unsaved; end\n", RUBY_VERSION.to_f, path)

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, unsaved, "class Corrected; end\n")
    assert_predicate index["OnDisk"], :itself
    assert_nil index["Corrected"]
  end

  test "update preserves the revision chain across garbage collection" do
    path = create_file("lib/example.rb", "class First; end\n")
    index = project_index_for(path)
    first = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    second = RuboCop::ProcessedSource.new("class Second; end\n", RUBY_VERSION.to_f, path)
    RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, first, second.raw_source)

    GC.start

    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.current_source?(index, second)
    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, second, "class Third; end\n")
    assert_predicate index["Third"], :itself
    assert_equal 2, RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(index)
  end

  test "update rejects a source whose backing file disappeared" do
    missing = project.path_of("lib/missing.rb")
    processed = RuboCop::ProcessedSource.new("class Missing; end\n", RUBY_VERSION.to_f, missing)

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.update(Object.new, processed, "class Other; end\n")
  end

  test "current_source? recognizes the corrected revision while its write is deferred" do
    path = create_file("lib/example.rb", "class Before; end\n")
    index = project_index_for(path)
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    corrected = RuboCop::ProcessedSource.new("class After; end\n", RUBY_VERSION.to_f, path)
    RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, corrected.raw_source)

    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.current_source?(index, corrected)
  end

  test "current_source? rejects a trusted revision after its backing file changes" do
    path = create_file("lib/example.rb", "class Before; end\n")
    index = project_index_for(path)
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    corrected = RuboCop::ProcessedSource.new("class After; end\n", RUBY_VERSION.to_f, path)
    RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, corrected.raw_source)
    File.binwrite(path, "class ConcurrentChange; end\n")

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.current_source?(index, corrected)
  end

  test "current_source? rejects a source whose backing file disappeared" do
    missing = project.path_of("lib/missing.rb")
    processed = RuboCop::ProcessedSource.new("class Missing; end\n", RUBY_VERSION.to_f, missing)

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.current_source?(Object.new, processed)
  end

  test "reliable? becomes false when Rubydex rejects a trusted revision" do
    path = create_file("lib/example.rb", "class Example; end\n")
    index = RejectingIndex.new
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, "class Corrected; end\n")
    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.reliable?(index)
  end

  test "reliable? preserves a rejected revision across garbage collection" do
    path = create_file("lib/example.rb", "class Example; end\n")
    index = RejectingIndex.new
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, "class Corrected; end\n")

    GC.start

    assert_not RuboCop::Callbacksystems::ProjectIndex::Freshness.reliable?(index)
    assert_equal 1, RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(index)
  end

  test "generation advances and invalidates derived graph readings" do
    path = create_file("lib/example.rb", "class Before; end\n")
    index = project_index_for(path)
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    references = RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(index)
    diagnostics = RuboCop::Callbacksystems::ProjectIndex::Diagnostics.for(index)
    reading = RuboCop::Callbacksystems::ProjectIndex::Reading.for(index)
    RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed, "class After; end\n")

    assert_equal 1, RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(index)
    assert_not_same references, RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(index)
    assert_not_same diagnostics, RuboCop::Callbacksystems::ProjectIndex::Diagnostics.for(index)
    assert_not_same reading, RuboCop::Callbacksystems::ProjectIndex::Reading.for(index)
  end

  private
    def project_index_for(path)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index([ path ]) || flunk("Expected Rubydex to build the project index")
    end

    class RejectingIndex
      def index_source(*)
        raise "cannot update"
      end
    end
end
