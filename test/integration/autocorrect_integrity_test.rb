require "test_helper"

# Every correcting cop is run to a fixed point over the sources its own tests declare, then with a comment planted above
# and beside every line its raw corrections touch, since a cop that cannot carry a comment should decline on its own.
class AutocorrectIntegrityTest < ActiveSupport::TestCase
  MARKER_TEXT = "autocorrect-integrity-marker"
  MARKER = "# #{MARKER_TEXT}"
  MARKER_PATTERN = /#{MARKER_TEXT}-\d+/
  RunResult = Data.define(:output, :correction_count, :touched_lines)

  test "no corrector drops a comment, breaks the syntax, or is held back" do
    cases = RecordedCases.new.to_a
    failures = cases.flat_map do |sample|
      sample.with_project do
        probe = Probe.new(sample)

        [ Convergence.new(sample, first_rewrite: probe.corrected).failure, *probe.failures ].compact
      end
    end

    assert_not_empty cases, "Load the cop tests before running the cross-corrector audit"
    assert_empty failures, failures.join("\n\n")
  end

  test "a correction held back on the original source fails the audit" do
    assert_equal 1, Probe.new(WithheldSample.new).failures.size
  end

  test "one held correction is found beside an accepted correction" do
    guarded = RunResult.new("first = 1\nsecond = 3\n", 1, [])
    unguarded = RunResult.new("first = (\nsecond = 3\n", 2, [])

    assert_predicate CorrectionComparison.new(guarded, unguarded), :held_back?
  end

  test "a rescued correction is not mistaken for one held back" do
    guarded = RunResult.new("value = 2 # kept\n", 1, [])
    unguarded = RunResult.new("value = 2\n", 1, [])

    assert_not_predicate CorrectionComparison.new(guarded, unguarded), :held_back?
  end

  test "tooling protection makes normal and bypassed partial corrections agree" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          # :nocov:
          # :nocov:
          @order = orders(:one)
          @user = users(:john)
        end

        test "reads order" do
          assert @order.valid?
        end

        test "reads user" do
          assert @user.valid?
        end
      end
    RUBY
    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          # :nocov:
          # :nocov:
          @order = orders(:one)
        end

        test "reads order" do
          assert @order.valid?
        end

        test "reads user" do
          assert users(:john).valid?
        end
      end
    RUBY
    sample = Case.new \
      RuboCop::Cop::Callbacksystems::SingleUseSetupVariable,
      original,
      "test/models/order_test.rb",
      nil,
      ProjectSnapshot.at(nil),
      nil
    guarded = sample.run(original)
    unguarded = sample.run(original, bypass: true)

    assert_equal corrected, guarded.output
    assert_equal guarded.output, unguarded.output
    assert_equal 1, guarded.correction_count
    assert_equal guarded.correction_count, unguarded.correction_count
  end

  test "a project snapshot restores a clean copy for every run" do
    root = Dir.mktmpdir
    original = File.join(root, "test", ".fixtures.yml")
    added = File.join(root, "added.rb")
    FileUtils.mkdir_p(File.dirname(original))
    File.binwrite(original, "users:\n")
    snapshot = ProjectSnapshot.at(root)
    FileUtils.rm_rf(root)

    snapshot.around do
      assert_equal "users:\n", File.binread(original)
      File.binwrite(added, "temporary\n")
    end

    snapshot.around do
      assert_equal "users:\n", File.binread(original)
      assert_not File.exist?(added)
    end

    assert_not Dir.exist?(root)
  ensure
    FileUtils.rm_rf(root) if root
  end

  private
    class RecordedCases
      include Enumerable

      delegate :each, to: :cases

      private
        def cases
          @cases ||= correcting_test_classes.flat_map { cases_in(it) }.uniq
        end

        def correcting_test_classes
          CopTestCase.descendants.select { it.cop_class&.support_autocorrect? }
        end

        def cases_in(test_class)
          test_class.public_instance_methods.grep(/\Atest_/).flat_map { cases_of(test_class.new(it)) }
        end

        def cases_of(test)
          [].tap do |recorded|
            test.extend(Recording.new(recorded))
            result = test.run

            raise result.failure unless result.passed?
          end
        end

        class Recording < Module
          def initialize(recorded)
            super()
            recorder = InvestigationRecorder.new(recorded)
            define_method(:cop_investigation) do |source, file: CopTestCase::DEFAULT_FILE, config: nil,
                project_sources: nil|
              recorder.record(self, source, file:, config:, project_sources:) do
                super(source, file:, config:, project_sources:)
              end
            end
          end

          private
            class InvestigationRecorder
              Input = Data.define(:source, :file, :config, :project_sources)

              def initialize(recorded)
                @recorded = recorded
              end

              def record(test, source, file:, config:, project_sources:)
                input = Input.new(source, file, config, project_sources)
                Investigation.new(recorded, test, input).record { yield }
              end

              private
                attr_reader :recorded

                class Investigation
                  delegate :source, :file, :config, :project_sources, to: :input

                  def initialize(recorded, test, input)
                    @recorded = recorded
                    @test = test
                    @input = input
                  end

                  def record
                    yield.tap { recorded << recorded_case }
                  end

                  private
                    attr_reader :recorded, :test, :input

                    def recorded_case
                      Case.new \
                        test.class.cop_class,
                        source,
                        file,
                        config,
                        ProjectSnapshot.at(project_root),
                        project_paths
                    end

                    def project_root
                      test.instance_variable_get(:@project)&.path if indexed_sources
                    end

                    def indexed_sources
                      @indexed_sources ||= project_sources || ({} if project_sources.nil? && test.class.project_indexed)
                    end

                    def project_paths
                      [ *indexed_sources.keys, file ].uniq if indexed_sources
                    end
                end
            end
        end
    end

    class Case < Data.define(:cop_class, :source, :file, :config, :project_snapshot, :project_paths)
      def corrected(source)
        run(source).output
      end

      def run(source, bypass: false)
        operation = -> do
          project_snapshot.write(file, source) if project_paths
          CorrectionRun.new(cop_class, source, investigation_file, config, project_index).materialize
        end

        bypass ? RuboCop::Callbacksystems::Autocorrection::Batch.bypassing(&operation) : operation.call
      end

      def with_project(&block)
        project_snapshot.around(&block)
      end

      private
        def investigation_file
          project_paths ? project_snapshot.path_of(file) : file
        end

        def project_index
          if project_paths
            RuboCop::ProjectIndexLoader.build_index(project_paths.map { project_snapshot.path_of(it) })
          end
        end
    end

    class CorrectionRun
      def initialize(cop_class, source, file, config, project_index = nil)
        @investigation = CopTestCase::CopInvestigation.new(cop_class, source, file, config, project_index)
      end

      def materialize
        output
        corrections
        self
      end

      def output
        @output ||= investigation.corrected_source
      end

      def correction_count
        corrections.size
      end

      def touched_lines
        @touched_lines ||= corrections.flat_map { lines_touched_by(it) }.uniq
      end

      private
        attr_reader :investigation

        def corrections
          @corrections ||= investigation.offenses.filter_map(&:corrector).reject(&:empty?)
        end

        def lines_touched_by(corrector)
          corrector.as_replacements.flat_map do |range, _text|
            (range.line..range.last_line).to_a
          end
        end
    end

    class ProjectSnapshot < Data.define(:root, :files)
      class << self
        def at(root)
          root ? new(root, files_in(root)) : new(nil, {})
        end

        private
          def files_in(root)
            Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).select { File.file?(it) }.to_h do |path|
              [ path.delete_prefix("#{root}/"), File.binread(path) ]
            end
          end
      end

      def around
        restore if root
        yield
      ensure
        FileUtils.rm_rf(root) if root
      end

      def write(path, source)
        File.binwrite(path_of(path), source)
      end

      def path_of(path)
        root && !path.start_with?(root) ? File.join(root, path) : path
      end

      private
        def restore
          FileUtils.rm_rf(root)
          FileUtils.mkdir_p(root)
          files.each do |relative_path, contents|
            path = File.join(root, relative_path)
            FileUtils.mkdir_p(File.dirname(path))
            File.binwrite(path, contents)
          end
        end
    end

    class Probe
      def initialize(sample)
        @sample = sample
      end

      def corrected
        guarded.output
      end

      def failures
        [ baseline_failure, *variant_failures ].compact
      end

      private
        attr_reader :sample

        def guarded
          @guarded ||= sample.run(sample.source)
        end

        def baseline_failure
          Failure.new(sample.cop_class, sample.source, unguarded.output) if comparison.held_back?
        end

        def comparison
          @comparison ||= CorrectionComparison.new(guarded, unguarded)
        end

        def unguarded
          @unguarded ||= sample.run(sample.source, bypass: true)
        end

        def variant_failures
          corrects? ? variants.map { Outcome.new(sample, it) }.select(&:failing?).map(&:failure) : []
        end

        def corrects?
          corrected != sample.source
        end

        def variants
          lines = sample.source.lines(chomp: true)
          CommentVariants.new(lines, touched_indexes_in(lines)).to_a
        end

        def touched_indexes_in(lines)
          unguarded.touched_lines.filter_map do |line|
            line.pred if line.between?(1, lines.size)
          end
        end
    end

    class Failure < Data.define(:cop_class, :input, :output)
      def to_s
        "#{cop_class.badge}\n--- given ---\n#{input}--- produced ---\n#{output}"
      end
    end

    class CorrectionComparison < Data.define(:guarded, :unguarded)
      def held_back?
        guarded.correction_count < unguarded.correction_count
      end
    end

    class Outcome
      def initialize(sample, variant)
        @sample = sample
        @variant = variant
      end

      def failing?
        !intact? || comparison.held_back?
      end

      def failure
        Failure.new(sample.cop_class, variant, output)
      end

      private
        attr_reader :sample, :variant

        def intact?
          rewritten.valid_syntax? && (marker_tokens_in(original) - marker_tokens_in(rewritten)).empty?
        end

        def rewritten
          @rewritten ||= RuboCop::ProcessedSource.new(guarded.output, RUBY_VERSION.to_f)
        end

        def guarded
          @guarded ||= sample.run(variant)
        end

        def marker_tokens_in(source)
          source.comments.flat_map { it.text.scan(MARKER_PATTERN) }
        end

        def original
          @original ||= RuboCop::ProcessedSource.new(variant, RUBY_VERSION.to_f)
        end

        def comparison
          @comparison ||= CorrectionComparison.new(guarded, unguarded)
        end

        def unguarded
          @unguarded ||= sample.run(variant, bypass: true)
        end

        def output
          comparison.held_back? ? unguarded.output : guarded.output
        end
    end

    class CommentVariants
      PLACEMENTS = %i[ above trailing ]

      def initialize(lines, indexes)
        @lines = lines
        @indexes = indexes
      end

      def to_a
        indexes.empty? ? [] : PLACEMENTS.flat_map { Placement.new(lines, indexes, it).to_a }.uniq
      end

      private
        attr_reader :lines, :indexes

        class Placement
          def initialize(lines, indexes, name)
            @lines = lines
            @indexes = indexes
            @name = name
          end

          def to_a
            if valid_markers? then [ source ]
            elsif indexes.one? then []
            else halves.map { self.class.new(lines, it, name) }.flat_map(&:to_a)
            end
          end

          private
            attr_reader :lines, :indexes, :name

            def valid_markers?
              parsed.valid_syntax? && parsed.comments.sum { it.text.scan(MARKER_PATTERN).size } == indexes.size
            end

            def parsed
              @parsed ||= RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
            end

            def source
              @source ||= "#{marked_lines.join("\n")}\n"
            end

            def marked_lines
              lines.flat_map.with_index { |line, index| marked_line(line, index) }
            end

            def marked_line(line, index)
              if marked.exclude?(index) then line
              elsif name == :above then [ "#{line[/\A */]}#{marker_for(index)}", line ]
              else "#{line} #{marker_for(index)}"
              end
            end

            def marked
              @marked ||= indexes.to_set
            end

            def marker_for(index)
              "#{MARKER}-#{index.next}"
            end

            def halves
              indexes.each_slice((indexes.size / 2.0).ceil)
            end
        end
    end

    class WithheldSample
      def source
        "value\n"
      end

      def run(source, bypass: false)
        bypass ? RunResult.new("#{source.chomp}(", 1, [ 1 ]) : RunResult.new(source, 0, [])
      end

      def cop_class
        RuboCop::Cop::Callbacksystems::Base
      end
    end

    class Convergence
      MINIMUM_PASSES = 20

      def initialize(sample, first_rewrite:)
        @sample = sample
        @first_rewrite = first_rewrite
        @states = Set[sample.source]
        @current = sample.source
        @converged = false
      end

      def failure
        advance_with(first_rewrite)
        (pass_limit - 1).times { advance unless finished? }

        recorded_failure || (Failure.new(sample.cop_class, sample.source, current) unless converged)
      end

      private
        attr_reader :sample, :first_rewrite, :states, :current, :converged, :recorded_failure

        def advance_with(rewritten)
          if rewritten == current
            converge
          elsif states.add?(rewritten)
            continue_with(rewritten)
          else
            fail_with(rewritten)
          end
        end

        def converge
          @converged = true
        end

        def continue_with(rewritten)
          @current = rewritten
        end

        def fail_with(rewritten)
          @recorded_failure = Failure.new(sample.cop_class, current, rewritten)
        end

        def pass_limit
          [ MINIMUM_PASSES, sample.source.lines.size * 2 ].max
        end

        def finished?
          converged || recorded_failure
        end

        def advance
          advance_with(sample.corrected(current))
        end
    end
end
