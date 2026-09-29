# Ensures every public method of a class or module has a test, found by the
# convention that a test description opens with the name of the method it
# covers. A public method is the API of the class, so one without a test is a
# promise nothing checks, and the naming convention is what lets a reader go
# from the method to its tests and back.
#
# Methods of private nested classes are implementation details and stay out,
# and so do methods a macro references (callbacks, delegates), since the macro
# is what exercises them. A method returning a plain literal needs no test that
# would only restate the literal. Scopes and methods in `class_methods` blocks
# count.
#
# Test files are located based on the source file path:
# - lib/foo/bar.rb -> test/lib/foo/bar_test.rb or test/foo/bar_test.rb
# - app/models/user.rb -> test/models/user_test.rb
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
  def external_dependency_checksum
    [
      RuboCop::Callbacksystems::Source::FilesChecksum.for("test/**/*_test.rb", root: project_root),
      RuboCop::Callbacksystems::Source::FilesChecksum.for("*.gemspec", root: project_root, include_contents: false)
    ].join
  end

  def on_new_investigation
    @path_mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(processed_source.file_path)
    @tested_methods = path_mapping.test_path ? TestedMethods.new(path_mapping.test_path, ruby_version:) : Set.new
  end

  def on_class(node)
    unless private_nested_class?(node)
      report_each TestCoverage.new(node, processed_source, path_mapping:, tested_methods:)
    end
  end

  alias on_module on_class

  private
    attr_reader :path_mapping, :tested_methods
    delegate :ruby_version, to: :processed_source, private: true

    class TestCoverage
      MESSAGE = "Public method `%<method>s` has no test. " \
        "Convention: tests begin with the method name followed by what it does, " \
        "e.g. `test \"%<method>s returns the expected value\" do`"
      EXCLUDED_METHODS = %i[ initialize ].to_set

      def initialize(node, processed_source, path_mapping:, tested_methods:)
        @node = node
        @processed_source = processed_source
        @path_mapping = path_mapping
        @tested_methods = tested_methods
      end

      def each_offense
        untested_methods.each { yield RuboCop::Callbacksystems::Offense.new(it.node, message_for(it)) }
      end

      private
        attr_reader :node, :processed_source, :path_mapping, :tested_methods

        delegate :file_path, to: :processed_source, private: true

        def untested_methods
          checked? ? testable_public_methods.reject { covered?(it) } : []
        end

        def checked?
          file_path.exclude?("/test/") && !lib_file_in_non_gem_project? && test_source_valid?
        end

        def lib_file_in_non_gem_project?
          file_path.match?(%r{(^|/)lib/}) && !path_mapping.gem_project?
        end

        def test_source_valid?
          path_mapping.test_path.nil? || tested_methods.valid?
        end

        def testable_public_methods
          RuboCop::Callbacksystems::Methods::Definitions.new(node).reject { exempt?(it) }
        end

        def exempt?(definition)
          EXCLUDED_METHODS.include?(definition.name) || returns_literal?(definition.node)
        end

        def returns_literal?(method_node)
          method_node.type?(:any_def) && method_node.body&.recursive_literal?
        end

        def covered?(definition)
          MethodCoverage.new(definition, tested: tested_methods, macro_referenced: macro_referenced_methods).covered?
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::Methods::MacroReferences.new(node.body).to_set
        end

        def message_for(definition)
          format(MESSAGE, method: definition.name)
        end

        # A scope a macro names is still API a test reads, so the macro exempts every method but a scope.
        class MethodCoverage
          def initialize(definition, tested:, macro_referenced:)
            @definition = definition
            @tested = tested
            @macro_referenced = macro_referenced
          end

          def covered?
            tested? || macro_referenced_non_scope?
          end

          private
            attr_reader :definition, :tested, :macro_referenced

            def tested?
              tested.include?(definition.name.to_s)
            end

            def macro_referenced_non_scope?
              macro_referenced.include?(definition.name) && !scope?
            end

            def scope?
              definition.node.send_type? && definition.node.method?(:scope)
            end
        end
    end

    class TestedMethods
      extend RuboCop::AST::NodePattern::Macros
      include Enumerable
      include RuboCop::Callbacksystems::Testing::CopHelpers
      include RuboCop::Callbacksystems::Helpers

      delegate :each, to: :names

      def initialize(test_file_path, ruby_version:)
        @test_file_path = test_file_path
        @ruby_version = ruby_version
      end

      def valid?
        processed_test_source&.valid_syntax? || false
      end

      private
        attr_reader :test_file_path, :ruby_version

        def names
          @names ||= descriptions.filter_map { it.split(/\s+/).first }
        end

        def descriptions
          nodes_in(processed_test_source&.ast, :any_block).filter_map { test_block?(it) }
        end

        def processed_test_source
          @processed_test_source ||= RuboCop::Callbacksystems::Source::FileAst.processed_source \
            test_file_path, ruby_version:
        end
    end
end
