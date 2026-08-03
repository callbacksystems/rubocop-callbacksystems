# Ensures tests are ordered following the method definition order in the source file. When test names start with a
# method name, they should appear in the same order as those methods are defined in the corresponding source file.
#
# This cop only runs on test files and requires the source file to exist.
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
  include RuboCop::Callbacksystems::TestCopHelpers

  GROUPING_MESSAGE = "Tests for `%<method>s` should be grouped together."
  ORDER_MESSAGE = "Test for `%<method>s` appears after `%<previous>s`, but `%<method>s` is defined first in source."

  def external_dependency_checksum
    RuboCop::Callbacksystems::ProjectFilesChecksum.for([ "app/**/*.rb", "lib/**/*.rb" ], root: project_root)
  end

  def on_new_investigation
    @investigation = Investigation.new(processed_source, test_blocks, method_positions)
    register_offenses
  end

  private
    def project_root
      @config.base_dir_for_path_parameters
    end

    def method_positions
      @method_positions ||= checkable? ? source_methods.each_with_index.to_a.uniq(&:first).to_h : {}
    end

    def checkable?
      path_mapping.test_file? && path_mapping.source_path && File.exist?(path_mapping.source_path)
    end

    def path_mapping
      @path_mapping ||= RuboCop::Callbacksystems::TestPathMapping.new(processed_source.file_path)
    end

    def source_methods
      source_methods_cache[path_mapping.source_path] ||= source_methods_for(path_mapping.source_path)
    end

    def source_methods_cache
      @source_methods_cache ||= {}
    end

    def source_methods_for(source_path)
      RuboCop::Callbacksystems::FileAst.ast(source_path)&.then do |tree|
        RuboCop::Callbacksystems::MethodCollector.new(tree).all.map(&:second)
      end || []
    end

    def register_offenses
      @investigation.each_offense.to_a.each_with_index do |(node, message), index|
        if index.zero?
          add_offense(node, message: message) { @investigation.rewrite(it) }
        else
          add_offense(node, message: message)
        end
      end
    end

    class Investigation
      def initialize(processed_source, test_nodes, method_positions)
        @processed_source = processed_source
        @test_nodes = test_nodes
        @method_positions = method_positions
      end

      def each_offense(&block)
        Ordering.new(tests, method_positions).each_offense(&block)
      end

      def rewrite(corrector)
        Reorder.new(processed_source, test_nodes, tests, method_positions, corrector).rewrite
      end

      private
        attr_reader :processed_source, :test_nodes, :method_positions

        def tests
          @tests ||= test_nodes.filter_map { test_entry_for(it) }
        end

        def test_entry_for(node)
          method_name = method_from_description_for(node.send_node.first_argument.value)
          [ node, method_name ] if method_name
        end

        def method_from_description_for(description)
          words = description.split(/\s+/)
          method_candidates(words.first, words.second).find { method_positions.key?(it) }
        end

        def method_candidates(first_word, second_word)
          return [ first_word.to_sym ] if second_word == "scope"

          [ first_word.to_sym, :"#{first_word}?", :"#{first_word}!" ]
        end
    end

    # An executable class-body statement is a hard boundary, so a correction cannot move a test across setup or
    # configuration.
    class Reorder
      include RuboCop::Cop::RangeHelp
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source, test_nodes, tests, method_positions, corrector)
        @processed_source = processed_source
        @test_nodes = test_nodes
        @tests = tests
        @method_positions = method_positions
        @corrector = corrector
      end

      def rewrite
        test_runs.each { reorder_run(it) }
      end

      private
        attr_reader :processed_source, :test_nodes, :tests, :method_positions, :corrector

        def test_runs
          test_nodes.sort_by { it.source_range.begin_pos }.slice_when do |left, right|
            interrupted_between?(left, right)
          end
        end

        def interrupted_between?(left, right)
          right_start = block_range_of(right).begin_pos
          right_start < left.source_range.end_pos ||
            !range_between(left.source_range.end_pos, right_start).source.strip.empty?
        end

        def block_range_of(node)
          range_between(block_start_of(node), node.source_range.end_pos)
        end

        def block_start_of(node)
          range = (leading_comments_of(node).first || node).source_range
          range.begin_pos - range.column
        end

        def leading_comments_of(node)
          contiguous_comments_above(node.first_line - 1, [])
        end

        def contiguous_comments_above(line, collected)
          comment = own_line_comment_at(line)
          comment ? contiguous_comments_above(line - 1, [ comment, *collected ]) : collected
        end

        def own_line_comment_at(line)
          processed_source.comments.find { it.loc.line == line && own_line_comment?(it) }
        end

        def reorder_run(run)
          replacements_for(run).each do |original, replacement|
            corrector.replace(block_range_of(original), block_range_of(replacement).source) unless original.equal?(replacement)
          end
        end

        def replacements_for(run)
          recognized = run.select { tests_by_node.key?(it) }
          recognized.zip(order(recognized))
        end

        def tests_by_node
          @tests_by_node ||= tests.to_h
        end

        def order(nodes)
          nodes.each_index
            .sort_by { [ method_positions.fetch(tests_by_node.fetch(nodes[it])), it ] }
            .map { nodes[it] }
        end
    end

    class Ordering
      def initialize(tests, method_positions)
        @tests = tests
        @method_positions = method_positions
        @seen = {}
        @last_position = -1
        @last_name = nil
      end

      def each_offense(&block)
        if block
          tests.each { |test_node, method_name| check_test_ordering(test_node, method_name, &block) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :tests, :method_positions, :seen
        attr_accessor :last_position, :last_name

        def check_test_ordering(test_node, method_name, &block)
          if seen.key?(method_name)
            yield test_node, format(GROUPING_MESSAGE, method: method_name) unless consecutive?(method_name, test_node)
          elsif method_positions[method_name] < last_position
            yield test_node, format(ORDER_MESSAGE, method: method_name, previous: last_name)
          else
            self.last_position = method_positions[method_name]
            self.last_name = method_name
          end
          seen[method_name] = test_node
        end

        def consecutive?(method_name, current_test)
          previous_index = tests.index { |test_node, _| test_node == seen[method_name] }
          current_index = tests.index { |test_node, _| test_node == current_test }

          (previous_index...current_index).all? { tests[it].second == method_name }
        end
    end
end
