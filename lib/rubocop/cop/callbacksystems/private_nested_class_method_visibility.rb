# Detects public methods in visually private nested classes that are never
# called from outside. When the project index confirms that no other file can
# reach or subclass the class, a method none of its local callers names is an
# implementation detail and belongs in the private section.
#
# @example
#   # bad - unused_method is public but never called from outside
#   class Foo
#     def process
#       Bar.new(node).used_method
#       nil
#     end
#
#     private
#       class Bar
#         def used_method; end
#         def unused_method; end  # should be private
#       end
#   end
#
#   # good - internal methods are private
#   class Foo
#     def process
#       Bar.new(node).used_method
#       nil
#     end
#
#     private
#       class Bar
#         def used_method; end
#
#         private
#           def internal_method; end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateNestedClassMethodVisibility < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support

  def on_new_investigation
    @file_references = FileReferences.new(processed_source.ast) if project_index
  end

  def on_class(node)
    if project_index_reliable?
      private_nested_classes_in(node).select { confined_without_descendants?(it) }.each do |nested_class|
        report_each UnusedPublicMethods.new(nested_class, references: file_references.for(nested_class))
      end
    end
  end

  alias on_module on_class

  private
    attr_reader :file_references

    def confined_without_descendants?(nested_class)
      confined_declaration_of(nested_class)&.then do |declaration|
        declaration.descendants.none? { it.name != declaration.name }
      end
    end

    # References in the whole file compared with those inside one nested class, indexed once for every reader.
    class FileReferences
      def initialize(root)
        @root = root
        @by_class = {}.compare_by_identity
      end

      def for(nested_class)
        by_class[nested_class] ||= ClassReferences.new(all, References.new(nested_class))
      end

      private
        attr_reader :root, :by_class

        def all
          @all ||= References.new(root)
        end

        class ClassReferences
          delegate :public_visibility_uncertain?, to: :all

          def initialize(all, inside)
            @all = all
            @inside = inside
          end

          def mentions_outside?(method_name)
            all.call_count(method_name) > inside.call_count(method_name) ||
              all.block_pass_count(method_name) > inside.block_pass_count(method_name) ||
              all.delegation_count(method_name) > inside.delegation_count(method_name) ||
              all.dynamic_delegation_count > inside.dynamic_delegation_count
          end

          def public_visibility_required?(method_name)
            all.public_visibility_count(method_name).positive?
          end

          private
            attr_reader :all, :inside
        end
    end

    class References
      include RuboCop::Callbacksystems::Helpers

      PUBLIC_LOOKUPS = %i[ protected public public_method public_send respond_to? try try! ]
      VISIBILITY_ENUMERATIONS = %i[
        instance_methods methods private_instance_methods private_methods protected_instance_methods
        protected_methods public_instance_methods public_methods singleton_methods
      ]

      def initialize(root)
        @evidence = RuboCop::Callbacksystems::Methods::ReferenceEvidence.for(root)
      end

      def call_count(name)
        call_counts.fetch(name, 0)
      end

      def public_visibility_count(name)
        explicit_call_counts.fetch(name, 0) + block_pass_count(name) + delegation_count(name) +
          public_lookup_counts.fetch(name, 0) + (evidence.literal_method_names.include?(name.to_s) ? 1 : 0)
      end

      def block_pass_count(name)
        block_pass_counts.fetch(name, 0)
      end

      def delegation_count(name)
        delegation_counts.fetch(name, 0)
      end

      def public_visibility_uncertain?
        dynamic_public_lookup? || dynamic_block_pass? || dynamic_delegation_count.positive? ||
          interpolated_name? || visibility_enumerated?
      end

      def dynamic_delegation_count
        @dynamic_delegation_count ||= evidence.calls.count { dynamic_delegation?(it) }
      end

      private
        attr_reader :evidence

        def call_counts
          @call_counts ||= evidence.calls.map(&:method_name).tally
        end

        def explicit_call_counts
          @explicit_call_counts ||= evidence.calls.filter_map do |send_node|
            send_node.method_name if send_node.receiver && !send_node.receiver.self_type?
          end.tally
        end

        def block_pass_counts
          @block_pass_counts ||= evidence.block_passes.filter_map { block_pass_name_of(it) }.tally
        end

        def block_pass_name_of(node)
          node.children.first.value if node.children.first&.sym_type?
        end

        def delegation_counts
          @delegation_counts ||= evidence.calls.flat_map { delegated_names_of(it) }.tally
        end

        def delegated_names_of(send_node)
          if delegate_macro?(send_node)
            RuboCop::Callbacksystems::Methods::DelegateMacro.new(send_node).target_method_names || []
          else
            []
          end
        end

        def public_lookup_counts
          @public_lookup_counts ||= public_lookups.filter_map { public_lookup_name_of(it) }.tally
        end

        def public_lookups
          @public_lookups ||= evidence.calls.select { PUBLIC_LOOKUPS.include?(it.method_name) }
        end

        def public_lookup_name_of(send_node)
          send_node.first_argument&.then do |argument|
            if argument.type?(:sym, :str)
              argument.value.to_sym if argument.value.to_s.valid_encoding?
            elsif argument.any_def_type?
              argument.method_name
            end
          end
        end

        def dynamic_public_lookup?
          public_lookups.any? { public_lookup_name_of(it).nil? }
        end

        def dynamic_block_pass?
          evidence.block_passes.any? do |block_pass|
            block_pass.children.first && !block_pass.children.first.sym_type?
          end
        end

        def dynamic_delegation?(send_node)
          delegate_macro?(send_node) && RuboCop::Callbacksystems::Methods::DelegateMacro.new(send_node).target_method_names.nil?
        end

        def interpolated_name?
          evidence.interpolated_literals.any?
        end

        def visibility_enumerated?
          evidence.calls.any? { VISIBILITY_ENUMERATIONS.include?(it.method_name) }
        end
    end

    class UnusedPublicMethods
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method `%<method>s` in visually private nested class `%<class>s` is never called from outside. " \
        "Make it private."

      # Ruby calls these structurally (a double splat calls `to_hash`, `case` calls `===`), so no source names them.
      PROTOCOL_METHODS = RuboCop::Callbacksystems::Methods::ImplicitInvocations::METHOD_NAMES

      def initialize(nested_class, references:)
        @nested_class = nested_class
        @references = references
      end

      def each_offense
        unused_public_methods.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :nested_class, :references

        def unused_public_methods
          if references && !references.public_visibility_uncertain?
            uncalled_public_methods
          else
            []
          end
        end

        def uncalled_public_methods
          public_methods_in(nested_class).reject { mentioned_outside?(it.method_name) }
        end

        # An instance travels beyond one file's reading, so any mention of the name outside the class counts as a use.
        def mentioned_outside?(method_name)
          PROTOCOL_METHODS.include?(method_name) || macro_referenced_methods.include?(method_name) ||
            references.mentions_outside?(method_name) || references.public_visibility_required?(method_name)
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::Methods::MacroReferences.new(nested_class.body).to_a
        end

        def message_for(method_node)
          format(MESSAGE, method: method_node.method_name, class: class_name)
        end

        def class_name
          nested_class.identifier.short_name
        end
    end
end
