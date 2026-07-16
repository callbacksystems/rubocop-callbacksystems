# Ensures all public methods in classes and modules have corresponding tests.
# Private nested class methods are excluded since they are implementation details.
# Methods referenced by macros (callbacks, delegates) are excluded.
# Methods returning a plain literal are excluded since a test would only restate the literal.
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
#   # good - method returning a plain literal needs no test
#   class User
#     def role
#       "member"
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Public method `%<method>s` has no test. " \
    "Convention: tests begin with the method name followed by what it does, " \
    "e.g. `test \"%<method>s returns the expected value\" do`"

  def external_dependency_checksum
    RuboCop::Callbacksystems::ProjectFilesChecksum.for("test/**/*_test.rb", root: project_root)
  end

  def on_class(node)
    return if private_nested_class?(node)

    Analysis.new(node, processed_source.file_path).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class

  private
    def project_root
      @config.base_dir_for_path_parameters
    end

    class Analysis
      EXCLUDED_METHODS = %i[initialize].to_set.freeze

      def initialize(node, file_path)
        @node = node
        @file_path = file_path
        @path_mapping = RuboCop::Callbacksystems::TestPathMapping.new(file_path)
        @test_file_path = path_mapping.find_test_file
      end

      def each_offense(&block)
        if block
          untested_methods.each { |method_node, method_name| yield method_node, format(MESSAGE, method: method_name) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node, :file_path, :test_file_path, :path_mapping

        def untested_methods
          return [] if skip?

          testable_public_methods.reject { |method_node, method_name| MethodCoverage.new(method_node, method_name, tested_methods, macro_referenced_methods).covered? }
        end

        def skip?
          file_path.include?("/test/") || lib_file_in_non_gem_project?
        end

        def lib_file_in_non_gem_project?
          file_path.match?(%r{(^|/)lib/}) && !path_mapping.gem_project?
        end

        def testable_public_methods
          RuboCop::Callbacksystems::MethodCollector.new(node).all.reject { |method_node, name| exempt?(method_node, name) }
        end

        def exempt?(method_node, name)
          EXCLUDED_METHODS.include?(name) || returns_literal?(method_node)
        end

        def returns_literal?(method_node)
          method_node.type?(:any_def) && (method_node.body&.recursive_literal? || false)
        end

        def tested_methods
          @tested_methods ||= test_file_path ? TestedMethodsCollector.new(test_file_path).all : Set.new
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::MacroReferencedMethods.for(node.body)
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
      include RuboCop::Callbacksystems::Helpers

      def initialize(test_file_path)
        @test_file_path = test_file_path
      end

      def all
        RuboCop::Callbacksystems::FileAst.ast(test_file_path)&.then do |ast|
          Set.new(ast.each_node(:block).filter_map { tested_method_name_in(it) })
        end || Set.new
      end

      private
        attr_reader :test_file_path

        def tested_method_name_in(node)
          if bare_send?(node.send_node) && node.method?(:test)
            node.send_node.first_argument&.then { it.value.split(/\s+/).first if it.str_type? }
          end
        end
    end
end
