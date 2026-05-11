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

  def on_new_investigation
    return unless checkable?

    order_violations.each { |node, message| add_offense(node, message: message) }
  end

  private
    def checkable?
      path_mapping.test_file? && path_mapping.source_path && File.exist?(path_mapping.source_path)
    end

    def path_mapping
      RuboCop::Callbacksystems::TestPathMapping.new(processed_source.file_path)
    end

    def source_methods
      source_methods_cache[path_mapping.source_path] ||= load_source_methods(path_mapping.source_path)
    end

    def source_methods_cache
      @source_methods_cache ||= {}
    end

    def load_source_methods(source_path)
      processed = RuboCop::AST::ProcessedSource.new(File.read(source_path), RUBY_VERSION.to_f, source_path)
      processed.ast ? RuboCop::Callbacksystems::MethodCollector.new(processed.ast).collect.map(&:second) : []
    rescue
      []
    end

    def order_violations
      return [] if source_methods.empty?

      method_positions = {}.tap do |hash|
        source_methods.each_with_index { |name, index| hash[name] ||= index }
      end
      tests = build_test_list(method_positions)
      tests.size >= 2 ? Ordering.new(tests, method_positions).detect : []
    end

    def build_test_list(method_positions)
      processed_source.ast.each_node(:block)
        .select { test_block?(it) }
        .filter_map { test_entry_for(it, method_positions) }
    end

    def test_entry_for(node, method_positions)
      method_name = method_from_description_for(test_block?(node), method_positions)
      [ node, method_name ] if method_name
    end

    def method_from_description_for(description, method_positions)
      words = description.split(/\s+/)
      build_method_candidates(words.first, words.second).find { method_positions.key?(it) }
    end

    def build_method_candidates(first_word, second_word)
      return [ first_word.to_sym ] if second_word == "scope"

      [ first_word.to_sym, :"#{first_word}?", :"#{first_word}!" ]
    end

    class Ordering
      attr_reader :tests, :method_positions, :seen
      attr_accessor :last_position, :last_name

      def initialize(tests, method_positions)
        @tests = tests
        @method_positions = method_positions
        @seen = {}
        @last_position = -1
        @last_name = nil
      end

      def detect
        tests.each_with_object([]) do |(test_node, method_name), violations|
          check_test_ordering(test_node, method_name, violations)
        end
      end

      private
        def check_test_ordering(test_node, method_name, violations)
          if seen.key?(method_name)
            violations << [ test_node, "Tests for `#{method_name}` should be grouped together." ] unless consecutive?(method_name, test_node)
          elsif method_positions[method_name] < last_position
            violations << [ test_node, "Test for `#{method_name}` appears after `#{last_name}`, but `#{method_name}` is defined first in source." ]
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
