# `rubocop -a` loops over the whole enabled set, and two cops rewriting the same region can leave something neither
# would produce alone. So each shape the suite declares is corrected by every correcting cop at once, the way a real run
# does, and the result has to still parse and to pass the `Lint` cops it passed before.
class ClashAudit
  MAX_PASSES = 5
  STYLE_CONFIG_PATH = File.expand_path("../../rubocop.yml", __dir__)
  PROBE_FILE = "app/models/report.rb"
  TEST_PROBE_FILE = "test/models/report_test.rb"

  # Shapes no single cop's test file carries: one needs two cops to want the same region, the rest hold a heredoc, which
  # nesting in a cop's own test heredoc would hide from the scanner that reads them.
  PROBES = [
    # `delegate :about, :about`: PreferDelegate folds a method into a macro that already names it.
    <<~RUBY,
      class Report
        delegate :about, to: :account, private: true

        private
          def about
            account.about
          end

          def account
            @account
          end
      end
    RUBY

    <<~RUBY,
      PROBES = [
        <<~SQL
          select 1
        SQL
      ].freeze
    RUBY

    <<~RUBY,
      QUERIES = {
        report: <<~SQL
          select 1
        SQL
      }.freeze
    RUBY

    <<~RUBY,
      class Report
        def render
          wrap(
            <<~TEXT
              hello
            TEXT
          )
        end
      end
    RUBY

    <<~RUBY,
      class Report
        def render
          wrap(<<~TEXT)
            hello
          TEXT
          nil
        end
      end
    RUBY

    <<~RUBY
      class Report
        def render
          body = <<~TEXT
            hello
          TEXT
          wrap(body)
        end
      end
    RUBY
  ].freeze

  # The same, for the cops that only look at test files.
  TEST_PROBES = [ <<~RUBY ].freeze
    class ReportTest < ActiveSupport::TestCase
      setup do
        @body = <<~TEXT
          hello
        TEXT
      end

      test "renders" do
        assert_equal "hello", @body.strip
      end
    end
  RUBY

  def failure_report
    failures.join("\n\n")
  end

  def failures
    @failures ||= sources.filter_map { failure_for(it) }
  end

  private
    # A body lifted out of a test heredoc is raw text, so one that escaped a backslash for the heredoc does not stand as
    # Ruby on its own.
    def sources
      @sources ||= (own_probes + FixerAudit.new.probe_sources).select(&:parses?)
    end

    def own_probes
      PROBES.map { Source.new(code: it, file: PROBE_FILE) } +
        TEST_PROBES.map { Source.new(code: it, file: TEST_PROBE_FILE) }
    end

    def failure_for(source)
      corrected = Correction.new(source, correcting_cops).result
      reason = regression_between(source, corrected)
      Clash.new(source, corrected, reason) if reason
    end

    def correcting_cops
      @correcting_cops ||= FixerAudit::CorrectingCops.new.classes
    end

    # Syntax first: an unparseable source reports no offenses at all.
    def regression_between(source, corrected)
      if corrected.parses?
        introduced = lint_names_in(corrected) - lint_names_in(source)
        "#{introduced.join(", ")} appeared after correcting" if introduced.any?
      else
        "the correction no longer parses"
      end
    end

    def lint_names_in(source)
      Investigation.new(source, lint_cops, lint_config).offenses.map(&:cop_name).uniq
    end

    # Code that stopped being correct, not code that stopped matching a style.
    def lint_cops
      @lint_cops ||= RuboCop::Cop::Registry.global.cops.select { enabled_lint?(it) }
    end

    def enabled_lint?(cop_class)
      cop_class.badge.department == :Lint && lint_config.for_cop(cop_class.badge.to_s)["Enabled"] == true
    end

    # The config a project gets, so a core cop this style guide turns off cannot fail the audit.
    def lint_config
      @lint_config ||= RuboCop::ConfigLoader.configuration_from_file(STYLE_CONFIG_PATH)
    end

    # A cop scoped to `test/` reports nothing on the same code under `app/`.
    class Source < Data.define(:code, :file)
      def to_s
        code
      end

      def parses?
        processed_source.valid_syntax?
      end

      def processed_source
        RuboCop::ProcessedSource.new(code, RUBY_VERSION.to_f, file)
      end
    end

    # A cop whose edit overlaps one already made in this pass is skipped and picked up by the next, as `rubocop -a`
    # does.
    class Correction
      def initialize(source, cops)
        @source = source
        @cops = cops
      end

      def result
        settled_from(source, MAX_PASSES)
      end

      private
        attr_reader :source, :cops

        def settled_from(current, passes_left)
          corrected = pass_over(current)
          if passes_left.zero? || corrected.code == current.code
            current
          else
            settled_from(corrected, passes_left - 1)
          end
        end

        def pass_over(current)
          investigation = Investigation.new(current, cops, CopTestCase.default_config)
          corrector = RuboCop::Cop::Corrector.new(investigation.processed_source)
          investigation.offenses.each { merge(corrector, it) }
          current.with(code: corrector.rewrite)
        end

        def merge(corrector, offense)
          corrector.merge!(offense.corrector) if offense.corrector
        rescue
          nil
        end
    end

    # Some cops carry state across files, `Lint/DuplicateMethods` among them, so they are built fresh for every
    # investigation.
    class Investigation
      # The corrector and the offenses have to be ranges over the same buffer.
      attr_reader :processed_source

      def initialize(source, cop_classes, config)
        @processed_source = source.processed_source
        @cop_classes = cop_classes
        @config = config
      end

      # A team assembles the forces cops depend on; `Lint/UselessAssignment` sees nothing without `VariableForce`.
      def offenses
        if processed_source.valid_syntax?
          RuboCop::Cop::Team.mobilize(cop_classes, config).investigate(processed_source).offenses
        else
          []
        end
      end

      private
        attr_reader :cop_classes, :config
    end

    class Clash
      def initialize(source, corrected, reason)
        @source = source
        @corrected = corrected
        @reason = reason
      end

      def to_s
        "#{reason}\n--- given ---\n#{source}--- produced ---\n#{corrected}"
      end

      private
        attr_reader :source, :corrected, :reason
    end
end
