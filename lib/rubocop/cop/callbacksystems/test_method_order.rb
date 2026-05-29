# Ensures tests are ordered following the method definition order in the source file.
# When test names start with a method name, they should appear in the same order
# as those methods are defined in the corresponding source file.
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
  include RuboCop::Callbacksystems::TestCopHelpers

  GROUPING_MESSAGE = "Tests for `%<method>s` should be grouped together."
  ORDER_MESSAGE = "Test for `%<method>s` appears after `%<previous>s`, but `%<method>s` is defined first in source."

  def on_new_investigation
    positions = method_positions
    Ordering.new(test_list_for(positions), positions).each_offense do |node, message|
      add_offense(node, message: message)
    end
  end

  private
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

    def test_list_for(method_positions)
      test_blocks.filter_map { test_entry_for(it, method_positions) }
    end

    def test_entry_for(node, method_positions)
      method_name = method_from_description_for(test_block?(node), method_positions)
      [ node, method_name ] if method_name
    end

    def method_from_description_for(description, method_positions)
      words = description.split(/\s+/)
      method_candidates(words.first, words.second).find { method_positions.key?(it) }
    end

    def method_candidates(first_word, second_word)
      return [ first_word.to_sym ] if second_word == "scope"

      [ first_word.to_sym, :"#{first_word}?", :"#{first_word}!" ]
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
