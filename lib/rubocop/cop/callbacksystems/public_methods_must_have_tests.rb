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
class RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests < RuboCop::Cop::Callbacksystems::Base
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
      parent = node.each_ancestor(:class, :module).first
      parent && private_nested_classes(parent).include?(node)
    end

    class Analysis
      EXCLUDED_METHODS = %i[initialize].to_set.freeze

      def initialize(node, file_path)
        @node = node
        @file_path = file_path
        @test_file_path = RuboCop::Callbacksystems::TestPathMapping.new(file_path).find_test_file
      end

      def public_methods_without_tests
        return [] if skip?

        testable_public_methods.reject { |method_node, method_name| MethodCoverage.new(method_node, method_name, tested_methods, macro_referenced_methods).covered? }
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
          Dir.glob("#{file_path.sub(%r{/lib/.*}, "")}/*.gemspec").any?
        end

        def testable_public_methods
          RuboCop::Callbacksystems::MethodCollector.new(node).collect.reject { |_, name| EXCLUDED_METHODS.include?(name) }
        end

        def tested_methods
          @tested_methods ||= test_file_path ? TestedMethodsCollector.new(test_file_path).collect : Set.new
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= node.body ? RuboCop::Callbacksystems::MacroReferencedMethods.new(node.body).collect : Set.new
        rescue
          Set.new
        end

        class MethodCoverage
          def initialize(method_node, method_name, tested_methods, macro_referenced_methods)
            @method_node = method_node
            @method_name = method_name
            @tested_methods = tested_methods
            @macro_referenced_methods = macro_referenced_methods
          end

          def covered?
            already_covered? || macro_referenced_non_scope?
          end

          private
            attr_reader :method_node, :method_name, :tested_methods, :macro_referenced_methods

            def already_covered?
              tested_methods.include?(method_name.to_s)
            end

            def macro_referenced_non_scope?
              macro_referenced_methods.include?(method_name) && !scope_node?
            end

            def scope_node?
              method_node.send_type? && method_node.method?(:scope)
            end
        end
    end

    class TestedMethodsCollector
      def initialize(test_file_path)
        @test_file_path = test_file_path
      end

      def collect
        return Set.new unless File.exist?(test_file_path)

        parse_ast&.then do |ast|
          Set.new(ast.each_node(:block).filter_map { tested_method_name(it) })
        end || Set.new
      end

      private
        attr_reader :test_file_path

        def parse_ast
          RuboCop::AST::ProcessedSource.new(File.read(test_file_path), RUBY_VERSION.to_f, test_file_path).ast
        rescue
          nil
        end

        def tested_method_name(node)
          return unless node.method?(:test) && node.receiver.nil?

          node.send_node.first_argument&.then { it.value.split(/\s+/).first if it.str_type? }
        end
    end
end
