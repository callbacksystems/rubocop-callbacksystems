require_relative "temporary_project"

class CopTestCase < ActiveSupport::TestCase
  include TemporaryProject

  DEFAULT_FILE = "test/example_test.rb"

  class_attribute :project_indexed, default: false

  class << self
    attr_accessor :cop_class
  end

  private
    def assert_no_offense(code, **investigation_options)
      investigation = cop_investigation(code, **investigation_options)
      message = "Expected no offenses but found: #{investigation.offenses.map(&:message).join(", ")}\nSource:\n#{code}"

      assert_empty investigation.offenses, message
    end

    # A test passes `config:` when its cop reads a core cop's settings, which the injected plugin defaults do not carry.
    def cop_investigation(source, file: DEFAULT_FILE, config: nil, project_sources: nil)
      project_sources = {} if project_sources.nil? && self.class.project_indexed
      project_index = project_index_for(project_sources.merge(file => source)) if project_sources
      file = project.path_of(file) if project_sources

      CopInvestigation.new(self.class.cop_class, source, file, config, project_index)
    end

    def project_index_for(sources)
      paths = sources.map { |path, source| create_file(path, source) }
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index(paths) || flunk("Expected Rubydex to build the project index")
    end

    def assert_correction(original, corrected, **investigation_options)
      investigation = cop_investigation(original, **investigation_options)

      assert_equal corrected, investigation.corrected_source, "Autocorrection did not produce expected result"
    end

    def assert_no_correction(source, **investigation_options)
      investigation = cop_investigation(source, **investigation_options)

      assert_equal source, investigation.corrected_source, "Expected the source to be left as written"
    end

    def assert_uncorrectable_offense(bad_code, **investigation_options)
      assert_offense(bad_code, **investigation_options).tap do |offenses|
        assert_equal :unsupported, offenses.first.status, "Expected the offense to carry no correction"
      end
    end

    def assert_offense(bad_code, count: nil, **investigation_options)
      cop_investigation(bad_code, **investigation_options).offenses.tap do |offenses|
        assert offenses.any?, "Expected an offense but found none.\nSource:\n#{bad_code}"
        assert_equal count, offenses.size, "Expected #{count} offenses.\nSource:\n#{bad_code}" if count
      end
    end

    class CopInvestigation
      delegate :offenses, to: :report

      def initialize(cop_class, source, file, settings = nil, project_index = nil)
        @cop_class = cop_class
        @source = source
        @file = file
        @settings = settings
        @project_index = project_index
      end

      def corrected_source
        corrector = RuboCop::Cop::Corrector.new(processed_source)
        report.offenses.each { corrector.merge!(it.corrector) if it.corrector }
        corrector.rewrite
      end

      private
        attr_reader :cop_class, :source, :file, :settings, :project_index

        def processed_source
          @processed_source ||= RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file)
        end

        def report
          @report ||= commissioner.investigate(processed_source)
        end

        def commissioner
          RuboCop::Cop::Commissioner.new([ cop ], [], raise_error: true)
        end

        def cop
          cop_class.new(configuration, autocorrect: true).tap { it.project_index = project_index }
        end

        def configuration
          RuboCop::Config.new(settings, file) if settings
        end
    end
end
