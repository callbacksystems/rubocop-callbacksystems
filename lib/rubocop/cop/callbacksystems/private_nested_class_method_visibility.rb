# Detects public methods in private nested classes that are never called from outside. If a method in a private nested
# class is only used internally, it should be private.
#
# @example
#   # bad - unused_method is public but never called from outside
#   class Foo
#     def process
#       Bar.new(node).used_method
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
  MESSAGE = "Method `%<method>s` in private nested class `%<class>s` is never called from outside. Make it private."

  def on_class(node)
    private_nested_classes_in(node).each do |nested_class|
      VisibilityCheck.new(node, nested_class).each_offense do |offense_node, message|
        add_offense(offense_node, message: message)
      end
    end
  end

  alias on_module on_class

  private
    class VisibilityCheck
      include RuboCop::Callbacksystems::Helpers

      # Called structurally by Ruby itself, so their names never appear near an instance.
      PROTOCOL_METHODS = %i[
        to_hash to_h to_str to_s to_ary to_a to_proc to_int to_i to_path
        == eql? hash <=> === each call inspect as_json to_json
        deconstruct deconstruct_keys
      ].freeze

      def initialize(parent_node, nested_class)
        @parent_node = parent_node
        @nested_class = nested_class
        @class_name = nested_class.identifier.short_name
      end

      def each_offense(&block)
        if block
          unused_public_methods.each { yield it, format(MESSAGE, method: it.method_name, class: class_name) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :parent_node, :nested_class, :class_name

        def unused_public_methods
          instances_stay_here? ? uncalled_public_methods : []
        end

        # Once an instance leaves, nothing in this file proves a method unused.
        def instances_stay_here?
          constructions.none? { handed_off?(it) }
        end

        def constructions
          nodes_outside(:send).select { builds_instance?(it) }
        end

        def nodes_outside(type)
          parent_node.body.each_node(type).reject { inside_nested_class?(it) }
        end

        def inside_nested_class?(node)
          node.each_ancestor(:class).any?(nested_class)
        end

        def builds_instance?(send_node)
          send_node.method?(:new) && send_node.receiver&.const_type? && send_node.receiver.short_name == class_name
        end

        def handed_off?(construction)
          construction.parent&.type?(:array, :hash, :pair) || passed_as_argument?(construction)
        end

        def passed_as_argument?(construction)
          construction.parent&.send_type? && !construction.parent.receiver.equal?(construction)
        end

        def uncalled_public_methods
          public_methods_in(nested_class).reject { mentioned_outside?(it.method_name) }
        end

        # One file cannot follow an instance out, so any mention of the name counts and only a name nobody says at all
        # is reported.
        def mentioned_outside?(method_name)
          external_names.include?(method_name)
        end

        def external_names
          @external_names ||= Set.new([ :initialize, *PROTOCOL_METHODS ] + called_names + block_pass_names + macro_referenced_methods)
        end

        def called_names
          nodes_outside(:send).map(&:method_name)
        end

        def block_pass_names
          nodes_outside(:block_pass).filter_map { it.children.first.value if it.children.first&.sym_type? }
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::MacroReferencedMethods.for(nested_class.body).to_a
        end
    end
end
