# Ensures tests follow the order of the methods they cover in the source file.
# A test file read beside its source then walks the class top to bottom, and a
# reader looking for the tests of a method finds them where the method sits
# instead of scanning the whole file for its name.
#
# A test names its method with the first word of its description, so only the
# tests opening with a method of the source are read, and the cop runs on test
# files whose source file exists.
#
# @example
#   # Source file (app/models/user.rb):
#   # def name; end
#   # def email; end
#   # def admin?; end
#
#   # bad - tests not in method order
#   test "email returns formatted email" do
#   end
#
#   test "name returns full name" do
#   end
#
#   # good - tests follow method order
#   test "name returns full name" do
#   end
#
#   test "email returns formatted email" do
#   end
#
#   test "admin? returns true for admins" do
#   end
#
class RuboCop::Cop::Callbacksystems::TestMethodOrder < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector
  include RuboCop::Callbacksystems::Testing::CopHelpers

  def external_dependency_checksum
    RuboCop::Callbacksystems::Source::FilesChecksum.for([ "app/**/*.rb", "lib/**/*.rb" ], root: project_root)
  end

  def on_new_investigation
    @method_positions = nil
    @path_mapping = nil

    report_each TestOrder.new(processed_source, blocks: test_blocks, positions: method_positions)
  end

  private
    def method_positions
      @method_positions ||= checkable? ? source_methods.each_with_index.to_a.uniq(&:first).to_h : {}
    end

    def checkable?
      test_file?(processed_source.file_path) && path_mapping.source_path && File.exist?(path_mapping.source_path)
    end

    def path_mapping
      @path_mapping ||= RuboCop::Callbacksystems::Testing::PathMapping.new(processed_source.file_path)
    end

    def source_methods
      source_methods_for(path_mapping.source_path)
    end

    def source_methods_for(source_path)
      source = RuboCop::Callbacksystems::Source::FileAst.processed_source \
        source_path, ruby_version: processed_source.ruby_version

      source&.valid_syntax? ? RuboCop::Callbacksystems::Methods::Definitions.new(source.ast).map(&:name) : []
    end

    class TestOrder
      Test = Data.define(:node, :name, :position)

      def initialize(processed_source, blocks:, positions:)
        @processed_source = processed_source
        @blocks = blocks
        @positions = positions
      end

      # Only the first offense carries the correction, since rewriting puts every test in order at once.
      def each_offense
        correction_available = reordering.applicable?
        offenses.each do |offense|
          yield correction_available ? correcting(offense) : offense
          correction_available = false
        end
      end

      private
        attr_reader :processed_source, :blocks, :positions

        delegate :rewrite, to: :reordering, private: true

        def reordering
          @reordering ||= Reordering.new(processed_source, blocks:, tests:)
        end

        def tests
          @tests ||= blocks.filter_map { test_for(it) }
        end

        def test_for(block)
          Description.new(block, positions).method_name&.then { Test.new(block, it, positions.fetch(it)) }
        end

        def offenses
          placements.filter_map(&:offense)
        end

        def placements
          Placements.new(tests)
        end

        def correcting(offense)
          RuboCop::Callbacksystems::Offense.new(offense.range, offense.message) { rewrite(it) }
        end
    end

    # Any executable statement between two tests is a hard boundary, so a correction cannot move a test across setup.
    class Reordering
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source, blocks:, tests:)
        @processed_source = processed_source
        @blocks = blocks
        @tests = tests
      end

      def rewrite(corrector)
        runs.select(&:reorderable?).each { it.rewrite(corrector) }
      end

      def applicable?
        runs.any?(&:reorderable?)
      end

      private
        attr_reader :processed_source, :blocks, :tests

        def runs
          @runs ||= blocks.sort_by { it.source_range.begin_pos }
            .slice_when { |left, right| interrupted_between?(left, right) }
            .map { Run.new(it, tests, processed_source) }
        end

        def interrupted_between?(left, right)
          left_end = statement_of(left).range.end_pos
          right_start = statement_of(right).begin_position
          right_start < left_end || content_in?(range_between(left_end, right_start).source)
        end

        def statement_of(node)
          RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def content_in?(source)
          source.lines.any? { it.strip.present? }
        end
    end

    # One uninterrupted run of test blocks, where a test the source does not know keeps its slot.
    class Run
      def initialize(blocks, tests, processed_source)
        @blocks = blocks
        @tests = tests
        @processed_source = processed_source
      end

      def rewrite(corrector)
        moved_indexes.each { corrector.replace(statement_of(recognized[it]).range, statement_of(ordered[it]).source) }
      end

      def reorderable?
        recognized != ordered && tooling_scope_kept?
      end

      private
        attr_reader :blocks, :tests, :processed_source

        def moved_indexes
          recognized.each_index.reject { recognized[it].equal?(ordered[it]) }
        end

        def recognized
          @recognized ||= blocks.filter_map { tests_by_node[it] }
        end

        def tests_by_node
          @tests_by_node ||= {}.compare_by_identity.tap do |index|
            tests.each { index[it.node] = it }
          end
        end

        def ordered
          @ordered ||= recognized.sort_by.with_index { |test, index| [ test.position, index ] }
        end

        def statement_of(test)
          statement_for(test.node)
        end

        def statement_for(node)
          RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def tooling_scope_kept?
          blocks.none? { statement_for(it).contains_tooling_comment? }
        end
    end

    class Description
      include RuboCop::Callbacksystems::Helpers

      def initialize(block, positions)
        @block = block
        @positions = positions
      end

      def method_name
        candidates.find { positions.key?(it) }
      end

      private
        attr_reader :block, :positions

        # A scope is named bare where a method might carry a `?` or `!`, so the word after the name tells the two apart.
        def candidates
          if first_word.nil? then []
          elsif scope? then [ first_word.to_sym ]
          else [ first_word.to_sym, :"#{first_word}?", :"#{first_word}!" ]
          end
        end

        def first_word
          words.first
        end

        def words
          @words ||= block.send_node.first_argument.value.split(/\s+/)
        end

        def scope?
          words.second == "scope"
        end
    end

    # Placements read the prefix once, carrying exactly the facts the next test needs.
    class Placements
      include Enumerable

      delegate :each, to: :placements

      def initialize(tests)
        @tests = tests
        @seen_names = Set.new
      end

      private
        attr_reader :tests, :seen_names, :previous, :anchor

        def placements
          @placements ||= tests.map { |test| placement_for(test).tap { remember(test) } }
        end

        def placement_for(test)
          Placement.new(test, repeated: seen_names.include?(test.name), grouped: previous&.name == test.name, anchor:)
        end

        def remember(test)
          seen_names << test.name
          @previous = test
          @anchor = test if anchor.nil? || test.position > anchor.position
        end
    end

    class Placement
      GROUPING_MESSAGE = "Tests for `%<method>s` should be grouped together."
      ORDER_MESSAGE = "Test for `%<method>s` appears after `%<previous>s`, but `%<method>s` is defined first in source."

      def initialize(test, repeated:, grouped:, anchor:)
        @test = test
        @repeated = repeated
        @grouped = grouped
        @anchor = anchor
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(test.node, message) if separated? || out_of_order?
      end

      private
        attr_reader :test, :anchor, :repeated, :grouped

        def separated?
          repeated? && !grouped?
        end

        def repeated?
          repeated
        end

        def grouped?
          grouped
        end

        def out_of_order?
          !repeated? && anchor && test.position < anchor.position
        end

        def message
          separated? ? format(GROUPING_MESSAGE, method: test.name) : order_message
        end

        def order_message
          format(ORDER_MESSAGE, method: test.name, previous: anchor.name)
        end
    end
end
