# Test helper for RuboCop Callbacksystems
$VERBOSE = nil

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_support"
require "active_support/test_case"
require "rubocop"
require "rubocop-callbacksystems"
require "minitest/autorun"

class CopTestCase < ActiveSupport::TestCase
  class << self
    attr_accessor :cop_class
  end

  private
    def cop_investigation(source, file: "test/example_test.rb")
      CopInvestigation.new(self.class.cop_class, source, file)
    end

    def assert_offense(bad_code, file: "test/example_test.rb")
      cop_investigation(bad_code, file: file).tap do |investigation|
        assert investigation.offenses.any?, "Expected an offense but found none.\nSource:\n#{bad_code}"
      end.offenses
    end

    def assert_no_offense(code, file: "test/example_test.rb")
      investigation = cop_investigation(code, file: file)

      assert_empty investigation.offenses, "Expected no offenses but found: #{investigation.offenses.map(&:message).join(", ")}\nSource:\n#{code}"
    end

    def assert_correction(original, corrected, file: "test/example_test.rb")
      investigation = CopInvestigation.new(self.class.cop_class, original, file)

      assert_equal corrected, investigation.corrected_source, "Autocorrection did not produce expected result"
    end

    class CopInvestigation
      delegate :offenses, to: :report

      def initialize(cop_class, source, file)
        @cop_class = cop_class
        @source = source
        @file = file
      end

      def corrected_source
        corrector = RuboCop::Cop::Corrector.new(processed_source)
        report.offenses.each { |offense| corrector.merge!(offense.corrector) if offense.corrector }
        corrector.rewrite
      end

      private
        attr_reader :cop_class, :source, :file

        def report
          @report ||= commissioner.investigate(processed_source)
        end

        def commissioner
          RuboCop::Cop::Commissioner.new([ cop_class.new ], [], raise_error: true)
        end

        def processed_source
          @processed_source ||= RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file)
        end
    end
end
