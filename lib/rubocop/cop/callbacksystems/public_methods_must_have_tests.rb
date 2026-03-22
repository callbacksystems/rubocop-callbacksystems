# Ensures all public methods in classes and modules have corresponding tests.
# Private nested class methods are excluded since they are implementation details.
# Methods referenced by macros (callbacks, delegates) are excluded.
# Scopes and methods in class_methods blocks are included.
#
# Test files are located based on the source file path:
# - lib/foo/bar.rb -> test/lib/foo/bar_test.rb or test/foo/bar_test.rb
# - app/models/user.rb -> test/models/user_test.rb
#
# Tests must follow the naming convention: test "method_name ..." do
#
# @example
#   # bad - public method without test
#   class User
#     def full_name
#       "#{first_name} #{last_name}"
#     end
#   end
#   # And test file has no test "full_name ..." block
#
#   # good - public method has test
#   class User
#     def full_name
#       "#{first_name} #{last_name}"
#     end
#   end
#   # test "full_name returns concatenated names" do ... end
#
class RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests < RuboCop::Cop::Base
  MESSAGE = "Public method `%<method>s` has no test. " \
    "Convention: tests begin with the method name followed by what it does, " \
    "e.g. `test \"%<method>s returns the expected value\" do`"

  def on_class(node)
    return if private_nested_class?(node)

    Analysis.new(node, processed_source.file_path).public_methods_without_tests.each do |method_node, method_name|
      add_offense(method_node, message: format(MESSAGE, method: method_name))
    end
  end

  alias on_module on_class

  private
    def private_nested_class?(node)
      PrivateNestedClassChecker.new(node).private?
    end

    class PrivateNestedClassChecker
      def initialize(node)
        @node = node
      end

      def private?
        return false unless parent_class_or_module

        in_private_section_of_parent?
      end

      private
        attr_reader :node

        def parent_class_or_module
          @parent_class_or_module ||= node.each_ancestor(:class, :module).first
        end

        def in_private_section_of_parent?
          return false unless parent_class_or_module.body

          in_private = false
          parent_class_or_module.body.each_child_node do |child|
            in_private = true if private_declaration?(child)
            return true if child == node && in_private
          end
          false
        end

        def private_declaration?(child)
          child.send_type? && child.method_name == :private && child.arguments.empty?
        end
    end

    class Analysis
      EXCLUDED_METHODS = %i[initialize].to_set.freeze

      def initialize(node, file_path)
        @node = node
        @file_path = file_path
        @test_file_path = TestFilePathResolver.new(file_path).resolve
      end

      def public_methods_without_tests
        return [] if skip?

        tested = test_file_path ? TestedMethodsCollector.new(test_file_path).collect : Set.new
        macro_referenced = collect_macro_referenced_methods

        testable_public_methods.filter_map do |method_node, method_name|
          next if tested.include?(method_name.to_s)
          next if macro_referenced.include?(method_name) && !scope_node?(method_node)

          [ method_node, method_name ]
        end
      end

      private
        attr_reader :node, :file_path, :test_file_path

        def skip?
          file_path.include?("/test/") || lib_file_in_non_gem_project?
        end

        def lib_file_in_non_gem_project?
          file_path.match?(%r{(^|/)lib/}) && !gem_project?
        end

        def gem_project?
          root = file_path.sub(%r{/lib/.*}, "")
          Dir.glob("#{root}/*.gemspec").any?
        end

        def testable_public_methods
          PublicMethodCollector.new(node).collect.reject { |_, name| EXCLUDED_METHODS.include?(name) }
        end

        def scope_node?(method_node)
          method_node.send_type? && method_node.method_name == :scope
        end

        def collect_macro_referenced_methods
          node.body ? RuboCop::Callbacksystems::MacroReferencedMethods.new(node.body).collect : Set.new
        rescue
          Set.new
        end
    end

    class TestFilePathResolver
      def initialize(file_path)
        @file_path = file_path
      end

      def resolve
        return unless file_path

        find_existing_test_file(candidate_paths)
      end

      private
        attr_reader :file_path

        def candidate_paths
          lib_paths + app_paths
        end

        def lib_paths
          return [] unless lib_file?

          [
            file_path.sub(%r{(^|/)lib/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/lib/#{Regexp.last_match(2)}_test.rb" },
            file_path.sub(%r{(^|/)lib/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb" }
          ]
        end

        def app_paths
          return [] unless app_file?

          [ file_path.sub(%r{(^|/)app/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb" } ]
        end

        def find_existing_test_file(paths)
          paths.find { |path| File.exist?(path) }
        end

        def lib_file?
          file_path.match?(%r{(^|/)lib/})
        end

        def app_file?
          file_path.match?(%r{(^|/)app/})
        end
    end

    class PublicMethodCollector
      attr_reader :node, :results

      def initialize(node)
        @node = node
        @results = []
      end

      def collect
        traverse(node.body, public_section: true)
        results
      end

      private
        def traverse(body, public_section:)
          return unless body

          add_public_method(body, public_section) || traverse_children(body, public_section: public_section)
        end

        def add_public_method(body, public_section)
          return unless public_section

          if %i[def defs].include?(body.type)
            results << [ body, body.method_name ]
          elsif scope_definition?(body)
            results << [ body, body.first_argument.value ]
          end
        end

        def traverse_children(body, public_section:)
          case body.type
          when :begin
            traverse_begin(body, public_section: public_section)
          when :sclass, :block
            traverse(body.body, public_section: true)
          end
        end

        def traverse_begin(body, public_section:)
          current_public = public_section
          body.each_child_node do |child|
            current_public = false if visibility_modifier?(child)
            traverse(child, public_section: current_public)
          end
        end

        def scope_definition?(node)
          node.send_type? && node.method_name == :scope && node.first_argument&.sym_type?
        end

        def visibility_modifier?(child)
          child.send_type? && %i[private protected].include?(child.method_name) && child.arguments.empty?
        end
    end

    class TestedMethodsCollector
      def initialize(test_file_path)
        @test_file_path = test_file_path
      end

      def collect
        return Set.new unless File.exist?(test_file_path)

        Set.new(File.read(test_file_path).scan(/test\s+["'](\w+[?!=]?|<=>|==)/).flatten)
      end

      private
        attr_reader :test_file_path
    end
end
