# Ensures all public methods in classes and modules have corresponding tests.
# Private nested class methods are excluded since they are implementation details.
#
# Test files are located based on the source file path:
# - lib/foo/bar.rb -> test/lib/foo/bar_test.rb
# - app/models/user.rb -> test/models/user_test.rb
# - app/controllers/users_controller.rb -> test/controllers/users_controller_test.rb
#
# Tests must follow the naming convention: test "method_name ..." do
#
# @example
#   # bad - public method without test
#   # In app/models/user.rb:
#   class User
#     def full_name
#       "#{first_name} #{last_name}"
#     end
#   end
#   # And test/models/user_test.rb has no test "full_name ..." block
#
#   # good - public method has test
#   # In app/models/user.rb:
#   class User
#     def full_name
#       "#{first_name} #{last_name}"
#     end
#   end
#   # And test/models/user_test.rb has:
#   # test "full_name returns concatenated names" do ... end
#
class RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests < RuboCop::Cop::Base
  MESSAGE = "Public method `%<method>s` has no test. " \
    "Convention: tests begin with the method name followed by what it does, " \
    "e.g. `test \"%<method>s returns the expected value\" do`"

  def on_class(node)
    return if private_nested_class?(node)

    Analysis.new(node, processed_source.file_path).public_methods_without_tests.each do |method_node|
      add_offense(method_node, message: format(MESSAGE, method: method_node.method_name))
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
      def initialize(node, file_path)
        @node = node
        @file_path = file_path
        @test_file_path = TestFilePathResolver.new(file_path).resolve
      end

      EXCLUDED_METHODS = %i[initialize].to_set.freeze

      def public_methods_without_tests
        return [] if should_skip?

        tested_methods = TestedMethodsCollector.new(test_file_path).collect
        testable_public_methods.reject { |method_node| tested_methods.include?(method_node.method_name.to_s) }
      end

      private
        attr_reader :node, :file_path, :test_file_path

        def should_skip?
          file_path.include?("/test/") || test_file_path.nil?
        end

        def testable_public_methods
          public_methods.reject { |method_node| excluded_method?(method_node) }
        end

        def public_methods
          PublicMethodCollector.new(node).collect
        end

        def excluded_method?(method_node)
          name = method_node.method_name
          EXCLUDED_METHODS.include?(name) || name.start_with?("on_")
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
      def initialize(node)
        @node = node
        @in_private = false
        @private_class_depth = 0
      end

      def collect
        return [] unless node.body

        body_children.select { |child| public_method?(child) }
      end

      private
        attr_reader :node

        def body_children
          return [ node.body ] if node.body.def_type?

          node.body.each_child_node.to_a
        end
        attr_accessor :in_private, :private_class_depth

        def public_method?(child)
          track_visibility(child)
          public_instance_method?(child)
        end

        def track_visibility(child)
          self.in_private = true if visibility_modifier?(child)
          self.private_class_depth += 1 if child.class_type? && in_private
        end

        def public_instance_method?(child)
          child.def_type? && !in_private && private_class_depth.zero?
        end

        def visibility_modifier?(child)
          child.send_type? && [ :private, :protected ].include?(child.method_name) && child.arguments.empty?
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
