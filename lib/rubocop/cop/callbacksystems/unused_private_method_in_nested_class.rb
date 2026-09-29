# Detects private methods of a visually private nested class that nothing
# calls. When the project index confirms that no other file reaches or reopens
# the class, a private method no line of the file names is dead code a reader
# still has to account for.
#
# @example
#   # bad - unused private method
#   class Foo
#     def process
#       Bar.new.run
#       nil
#     end
#
#     private
#       class Bar
#         def run
#           helper
#         end
#
#         private
#           def helper; end
#           def unused; end  # never called
#       end
#   end
#
#   # good - all private methods are used
#   class Foo
#     def process
#       Bar.new.run
#       nil
#     end
#
#     private
#       class Bar
#         def run
#           helper
#         end
#
#         private
#           def helper; end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::UnusedPrivateMethodInNestedClass < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support

  def on_new_investigation
    @file_references = FileReferences.new(processed_source.ast) if project_index
  end

  def on_class(node)
    if project_index_reliable?
      private_nested_classes_in(node).each do |nested_class|
        confined_declaration_of(nested_class)&.then do |declaration|
          report_each UnusedMethods.new(nested_class, declaration:, references: file_references)
        end
      end
    end
  end

  alias on_module on_class

  private
    attr_reader :file_references

    # Every source-level way the file can name or discover one of the nested class's methods, indexed once.
    class FileReferences
      include RuboCop::Callbacksystems::Helpers

      NAME_PREFIX_PATTERN = /[a-zA-Z_]\w*\z/
      DYNAMIC_METHOD_LOOKUPS = %i[
        send __send__ public_send method public_method private_method instance_method public_instance_method
        respond_to? method_defined? public_method_defined? protected_method_defined? private_method_defined?
        alias_method
      ]
      METHOD_ENUMERATIONS = %i[
        methods public_methods protected_methods private_methods singleton_methods
        instance_methods public_instance_methods protected_instance_methods private_instance_methods
      ]

      def initialize(root)
        @evidence = RuboCop::Callbacksystems::Methods::ReferenceEvidence.for(root)
      end

      def complete?
        dynamic_calls_resolved? && !methods_enumerated?
      end

      def include?(method_name)
        called_methods.include?(method_name) || dynamically_called_methods.include?(method_name) ||
          aliased_methods.include?(method_name) || macro_referenced_methods.include?(method_name) ||
          literal_method_names.include?(method_name.to_s) ||
          literal_method_prefixes.any? { method_name.to_s.start_with?(it) }
      end

      private
        attr_reader :evidence

        delegate :macro_referenced_methods, :literal_method_names, to: :evidence, private: true

        def dynamic_calls_resolved?
          dynamic_calls.all? do |send_node|
            method_name_arguments_of(send_node).all? { it.type?(:sym, :str) }
          end
        end

        def dynamic_calls
          @dynamic_calls ||= evidence.calls.select { DYNAMIC_METHOD_LOOKUPS.include?(it.method_name) }
        end

        def method_name_arguments_of(send_node)
          send_node.method?(:alias_method) ? send_node.arguments : [ send_node.first_argument ].compact
        end

        def methods_enumerated?
          evidence.calls.any? { METHOD_ENUMERATIONS.include?(it.method_name) }
        end

        def called_methods
          @called_methods ||= evidence.calls.to_set(&:method_name)
        end

        def dynamically_called_methods
          @dynamically_called_methods ||= dynamic_calls.flat_map do |send_node|
            method_name_arguments_of(send_node).filter_map { literal_method_name_of(it) }
          end.to_set
        end

        def literal_method_name_of(literal)
          literal.value.to_s.then { it.to_sym if it.valid_encoding? }
        end

        def aliased_methods
          @aliased_methods ||= evidence.alias_nodes.flat_map do |alias_node|
            alias_node.children.filter_map { literal_method_name_of(it) if it.type?(:sym, :str) }
          end.to_set
        end

        def literal_method_prefixes
          @literal_method_prefixes ||= evidence.interpolated_literals.filter_map do |literal|
            interpolation_prefix(literal)
          end.to_set
        end

        def interpolation_prefix(node)
          if node.children.any? { !it.str_type? }
            node.children.first.then { it.value.to_s.scrub[NAME_PREFIX_PATTERN] if it.str_type? }
          end
        end
    end

    class UnusedMethods
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Private method `%<method>s` in nested class `%<class>s` is never called. Remove it."
      STRUCTURAL_METHODS = RuboCop::Callbacksystems::Methods::ImplicitInvocations::METHOD_NAMES

      def initialize(nested_class, declaration:, references:)
        @nested_class = nested_class
        @declaration = declaration
        @references = references
      end

      def each_offense
        unused_methods.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :nested_class, :declaration, :references

        def unused_methods
          provable? ? uncalled_methods : []
        end

        # A superclass calls the hooks its subclass overrides, and that call is nowhere in this file.
        def provable?
          nested_class.parent_class.nil? && !subclassed_elsewhere? && references.complete?
        end

        def subclassed_elsewhere?
          declaration.descendants.any? { it.name != declaration.name }
        end

        def uncalled_methods
          private_methods_in(nested_class).reject do |method_node|
            STRUCTURAL_METHODS.include?(method_node.method_name) || override?(method_node.method_name) ||
              referenced?(method_node.method_name)
          end
        end

        def override?(method_name)
          declaration.find_member("#{method_name}()", only_inherited: true).present?
        end

        def referenced?(method_name)
          references.include?(method_name)
        end

        def message_for(method_node)
          format(MESSAGE, method: method_node.method_name, class: nested_class.identifier.short_name)
        end
    end
end
