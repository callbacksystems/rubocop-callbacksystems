require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::SupportTest < ActiveSupport::TestCase
  include TemporaryProject

  test "external_dependency_checksum is shared by readers of one index" do
    path = create_file("lib/example.rb", "class Example; end\n")
    index = project_index_for(path)

    assert_same Probe.new(index).external_dependency_checksum, Probe.new(index).external_dependency_checksum
    assert_nil Probe.new.external_dependency_checksum
  end

  test "project_index_reliable? accepts a complete static project" do
    source = "class Example; end\n"
    path = create_file("lib/example.rb", source)
    index = project_index_for(path)

    probe = Probe.new(index, path:, source:)

    assert probe.index_reliable?
    assert probe.index_reliable?
  end

  test "project_index_reliable? rejects reflection introduced into the same index" do
    source = "class Example; end\n"
    path = create_file("lib/example.rb", source)
    index = project_index_for(path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    corrected = "#{source}Object.const_get(:Example)\n"

    assert Probe.new(index, processed_source:).index_reliable?
    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed_source, corrected)
    assert_not Probe.new(index, path:, source: corrected).index_reliable?
  end

  test "project_index_reliable? accepts a revision after opaque reflection is removed" do
    source = "class Example; end\nObject.const_get(:Example)\n"
    path = create_file("lib/example.rb", source)
    index = project_index_for(path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    corrected = "class Example; end\n"

    assert_not Probe.new(index, processed_source:).index_reliable?
    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, processed_source, corrected)
    assert Probe.new(index, path:, source: corrected).index_reliable?
  end

  test "project_declaration_reliable? localizes invalid method visibility" do
    source = <<~RUBY
      class Container
        class Reliable; end
        class Unreliable
          def process; end
          public ENV.fetch("METHOD", :process)
        end
      end
    RUBY
    path = create_file("lib/container.rb", source)
    index = project_index_for(path)

    probe = Probe.new(index)

    assert probe.declaration_reliable?(index["Container::Reliable"])
    assert_not probe.declaration_reliable?(index["Container::Unreliable"])
  end

  private
    def project_index_for(path)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index([ path ]) || flunk("Expected Rubydex to build the project index")
    end

    class Probe
      include RuboCop::Callbacksystems::ProjectIndex::Support

      def initialize(project_index = nil, path: nil, source: nil, processed_source: nil)
        @project_index = project_index
        @processed_source = if processed_source
          processed_source
        elsif source
          RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        end
      end

      def declaration_reliable?(declaration)
        project_declaration_reliable?(declaration)
      end

      def index_reliable?
        project_index_reliable?
      end

      private
        attr_reader :processed_source, :project_index
    end
end
