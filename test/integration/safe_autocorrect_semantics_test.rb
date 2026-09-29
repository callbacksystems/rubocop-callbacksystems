require "test_helper"
require "stringio"

class SafeAutocorrectSemanticsTest < ActiveSupport::TestCase
  test "every correction declared safe has an executable semantic scenario" do
    assert_equal configured_safe_cops, scenarios.map(&:cop_name).sort
  end

  test "safe corrections preserve return values, effects, and exceptions" do
    failures = scenarios.filter_map(&:failure)

    assert_empty failures, failures.join("\n\n")
  end

  private
    Result = Data.define(:value, :output, :error)

    def configured_safe_cops
      YAML.load_file(RuboCop::Callbacksystems::Plugin::CONFIGURATION_PATH).filter_map do |name, settings|
        name if settings.is_a?(Hash) && settings["SafeAutoCorrect"]
      end.sort
    end

    def scenarios
      SCENARIOS
    end

    class Execution
      def initialize(source)
        @source = source
      end

      def result
        @output = StringIO.new
        @previous_output = $stdout
        $stdout = output

        evaluated_result
      ensure
        $stdout = previous_output
      end

      private
        attr_reader :source, :output, :previous_output

        def evaluated_result
          Result.new(Module.new.module_eval(source, "(safe autocorrect scenario)", 1), output.string, nil)
        rescue => error
          Result.new(nil, output.string, [ error.class.name, error.message ])
        end
    end

    class Scenario
      attr_reader :cop_class, :source
      delegate :cop_name, to: :cop_class

      def initialize(cop_class, source)
        @cop_class = cop_class
        @source = source
      end

      def failure
        if corrected_source == source
          "#{cop_name} did not correct its semantic scenario."
        elsif original_result != corrected_result
          <<~MESSAGE
            #{cop_name} changed runtime behavior.
            Original:  #{original_result.inspect}
            Corrected: #{corrected_result.inspect}
          MESSAGE
        end
      end

      private
        def corrected_source
          @corrected_source ||= CopTestCase::CopInvestigation.new(cop_class, source, "example.rb").corrected_source
        end

        def original_result
          @original_result ||= Execution.new(source).result
        end

        def corrected_result
          @corrected_result ||= Execution.new(corrected_source).result
        end
    end

    SCENARIOS = [
      Scenario.new(RuboCop::Cop::Callbacksystems::BuilderMethodParentheses, <<~RUBY),
        class Builder
          def self.new(**attributes)
            attributes
          end
        end

        events = []
        value = Builder.new status: events << :built
        print "built"
        [ value, events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::CollapseMultilineExpression, <<~RUBY),
        events = []
        value = [
          events << :first,
          events << :second
        ]
        print events.join(":")
        [ value, events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::EmptyLineBeforeMethod, <<~RUBY),
        class Subject
          VALUE = 1
          def call
            :called
          end
        end

        [ Subject::VALUE, Subject.new.call ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::EmptyLineBetweenSections, <<~RUBY),
        class Subject
          VALUE = 1
          attr_reader :value

          def initialize
            @value = VALUE
          end
        end

        Subject.new.value
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::ExpandedEmptyClassOrModule, <<~RUBY),
        class Marker; end

        [ Marker.is_a?(Class), Marker.instance_methods(false) ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::NoLocalVariableReturn, <<~RUBY),
        class Subject
          def call(events)
            result = events << :calculated
            result
          end
        end

        events = []
        [ Subject.new.call(events), events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::NoSectionDividerComments, <<~RUBY),
        events = []
        # ===== Execution =====
        value = events << :ran
        print "ran"
        [ value, events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::PreferPositiveWrap, <<~RUBY),
        class Subject
          def initialize(ready, events, fail: false)
            @ready = ready
            @events = events
            @fail = fail
          end

          def call
            return :skipped unless @ready
            @events << :started
            raise "boom" if @fail
            :done
          end
        end

        skipped_events = []
        completed_events = []
        failed_events = []
        skipped = Subject.new(false, skipped_events).call
        completed = Subject.new(true, completed_events).call
        failure = begin
          Subject.new(true, failed_events, fail: true).call
        rescue StandardError => error
          [ error.class.name, error.message ]
        end
        [ skipped, skipped_events, completed, completed_events, failure, failed_events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::ReflowComments, <<~RUBY),
        # A comment that stops
        # mid-sentence.
        events = [ :read ]
        print "read"
        [ events.last, events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::SingleLineSetupBlock, <<~RUBY),
        def self.setup(events)
          yield events
        end

        events = []
        result = setup(events) do |entries|
          entries << :prepared
        end
        print "prepared"
        [ result, events ]
      RUBY
      Scenario.new(RuboCop::Cop::Callbacksystems::SpaceInsidePercentLiteral, <<~RUBY)
        events = []
        values = %i[one two]
        events << values.length
        [ values, events ]
      RUBY
    ]
end
