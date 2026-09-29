require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::CacheTest < ActiveSupport::TestCase
  include TemporaryProject

  test "for reuses a reading of the same project index" do
    project_index = Object.new

    assert_same Reading.for(project_index), Reading.for(project_index)
  end

  test "for distinguishes equal project indexes by identity" do
    first_index = ProjectIndex.new([])
    second_index = ProjectIndex.new([])

    assert_equal first_index, second_index
    assert_not_same Reading.for(first_index), Reading.for(second_index)
  end

  test "for replaces the previous project index reading" do
    first_index = Object.new
    reading = Reading.for(first_index)
    Reading.for(Object.new)

    assert_not_same reading, Reading.for(first_index)
  end

  test "for keeps each consumer reading separate" do
    project_index = Object.new
    reading = Reading.for(project_index)
    other_reading = Class.new(Reading)

    assert_instance_of other_reading, other_reading.for(project_index)
    assert_same reading, Reading.for(project_index)
  end

  test "for replaces a reading after an in-memory project correction" do
    path = create_file("lib/example.rb", "class Before; end\n")
    flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?
    project_index = RuboCop::ProjectIndexLoader.build_index([ path ])
    reading = Reading.for(project_index)
    processed_source = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)

    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update \
      project_index, processed_source, "class After; end\n"
    assert_not_same reading, Reading.for(project_index)
    assert_same Reading.for(project_index), Reading.for(project_index)
  end

  private
    ProjectIndex = Data.define(:documents)

    class Reading < Data.define(:project_index)
      extend RuboCop::Callbacksystems::ProjectIndex::Cache
    end
end
