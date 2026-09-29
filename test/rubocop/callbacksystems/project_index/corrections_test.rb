require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::CorrectionsTest < ActiveSupport::TestCase
  include TemporaryProject

  Cop = Data.define(:project_index)

  test "apply_correction refreshes one shared graph and delegates the write" do
    path = create_file("lib/example.rb", "class Before; end\n")
    index = project_index_for(path)
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    writer = Writer.new([ Cop.new(index) ])

    2.times do
      assert_equal :written, writer.correct(processed, "class After; end\n")
    end

    assert_predicate index["After"], :itself
    assert_equal 2, RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(index)
  end

  test "apply_correction delegates without a project graph" do
    path = create_file("lib/example.rb", "class Example; end\n")
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    writer = Writer.new([ Cop.new(nil) ])

    assert_equal :written, writer.correct(processed, "class Corrected; end\n")
  end

  test "apply_correction does not choose between different project graphs" do
    path = create_file("lib/example.rb", "class Example; end\n")
    processed = RuboCop::ProcessedSource.from_file(path, RUBY_VERSION.to_f)
    writer = Writer.new([ Cop.new(Object.new), Cop.new(Object.new) ])

    assert_equal :written, writer.correct(processed, "class Corrected; end\n")
  end

  private
    def project_index_for(path)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index([ path ]) || flunk("Expected Rubydex to build the project index")
    end

    class Writer
      prepend RuboCop::Callbacksystems::ProjectIndex::Corrections

      attr_reader :cops

      def initialize(cops)
        @cops = cops
      end

      def correct(processed_source, new_source)
        apply_correction(processed_source, new_source)
      end

      private
        def apply_correction(*)
          :written
        end
    end
end
