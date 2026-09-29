require "test_helper"

class RuboCop::Cop::Callbacksystems::BaseTest < ActiveSupport::TestCase
  test "report preserves an absent correction and the comment-rewriting mode" do
    offense = RuboCop::Callbacksystems::Offense.new(:range, "message", correcting: false) { flunk }
    cop = RecordingCop.new

    cop.report_one(Analysis.new([ offense ]), rewrites_comments: true)

    assert_nil cop.reports.first.correction
    assert cop.reports.first.options[:rewrites_comments]
  end

  test "report passes through a correction that is present" do
    correction = ->(_corrector) { :corrected }
    offense = RuboCop::Callbacksystems::Offense.new(:range, "message", &correction)
    cop = RecordingCop.new

    cop.report_one(Analysis.new([ offense ]))

    assert_same correction, cop.reports.first.correction
  end

  test "report_each preserves absent corrections and the comment-rewriting mode" do
    offenses = [
      RuboCop::Callbacksystems::Offense.new(:first, "first"),
      RuboCop::Callbacksystems::Offense.new(:second, "second", correcting: false) { raise "must not run" }
    ]
    cop = RecordingCop.new

    cop.report_many(Analysis.new(offenses), rewrites_comments: true)

    assert cop.reports.all? { it.correction.nil? }
    assert cop.reports.all? { it.options[:rewrites_comments] }
  end

  test "add_offense reserves a source range only once" do
    processed = RuboCop::ProcessedSource.new("work\n", RUBY_VERSION.to_f, "example.rb")
    cop = ReservationCop.new(nil, autocorrect: true)
    report = RuboCop::Cop::Commissioner.new([ cop ], [], raise_error: true).investigate(processed)

    assert_equal 1, report.offenses.size
  end

  test "source_comments sees comments introduced while reusing one cop" do
    commissioner = commissioner_for(RuboCop::Cop::Callbacksystems::PreferExtractAssociated)
    first_report = report_for("posts.preload(:author).map(&:author)", commissioner:)
    second_report = report_for(<<~RUBY, commissioner:)
      posts.preload(
        # Keep.
        :author
      ).map(&:author)
    RUBY

    assert_equal :corrected, first_report.offenses.first.status
    assert_equal :unsupported, second_report.offenses.first.status
  end

  test "source_comments forgets removed comments while reusing a cop mixin" do
    commissioner = commissioner_for(RuboCop::Cop::Callbacksystems::PreferStringifyKeys)
    first_report = report_for(<<~RUBY, commissioner:)
      hash.transform_keys(
        # Keep.
        &:to_s
      )
    RUBY
    second_report = report_for("configuration_options.transform_keys(&:to_s)", commissioner:)

    assert_equal :unsupported, first_report.offenses.first.status
    assert_equal :corrected, second_report.offenses.first.status
  end

  private
    def commissioner_for(cop_class)
      cop = cop_class.new(nil, autocorrect: true)

      RuboCop::Cop::Commissioner.new([ cop ], [], raise_error: true)
    end

    def report_for(source, commissioner:)
      processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "example.rb")

      commissioner.investigate(processed_source)
    end

    class Analysis
      def initialize(offenses)
        @offenses = offenses
      end

      def offense
        offenses.first
      end

      def each_offense(&block)
        offenses.each(&block)
      end

      private
        attr_reader :offenses
    end

    class RecordingCop < RuboCop::Cop::Callbacksystems::Base
      Report = Data.define(:range, :options, :correction)

      attr_reader :reports

      def initialize
        super(nil, autocorrect: false)
        @reports = []
      end

      def report_one(analysis, rewrites_comments: false)
        report(analysis, rewrites_comments:)
      end

      def report_many(analyses, rewrites_comments: false)
        report_each(analyses, rewrites_comments:)
      end

      def add_offense(range, **options, &correction)
        reports << Report.new(range, options, correction)
      end
    end

    class ReservationCop < RuboCop::Cop::Callbacksystems::Base
      extend RuboCop::Cop::AutoCorrector

      def on_send(node)
        2.times { add_offense(node, message: "Duplicate offense.") }
      end
    end
end
