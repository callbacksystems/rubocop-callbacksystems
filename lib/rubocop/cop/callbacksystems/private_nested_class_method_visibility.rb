# Detects public methods in private nested classes that are never called from outside.
# If a method in a private nested class is only used internally, it should be private.
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
          public_methods_in(nested_class).reject { external_calls.include?(it.method_name) }
        end

        def external_calls
          @external_calls ||= Set.new([ :initialize ] + direct_calls + variable_calls + block_pass_calls + macro_referenced_methods)
        end

        def direct_calls
          external_sends.filter_map do |send_node|
            send_node.method_name if instance_method_call?(send_node.receiver)
          end
        end

        def external_sends
          @external_sends ||= parent_node.body.each_node(:send).reject { inside_nested_class?(it) }
        end

        def inside_nested_class?(node)
          node.each_ancestor(:class).any?(nested_class)
        end

        def instance_method_call?(node)
          node&.send_type? &&
            node.method?(:new) &&
            node.receiver&.const_type? &&
            node.receiver.short_name == class_name
        end

        def variable_calls
          parent_node.body.each_node(:lvasgn, :ivasgn).flat_map { calls_on_assigned_variable(it) }
        end

        def calls_on_assigned_variable(assignment)
          if instance_method_call?(assignment.expression)
            external_sends.filter_map do |send_node|
              send_node.method_name if call_on_variable?(send_node, assignment.name)
            end
          else
            []
          end
        end

        def call_on_variable?(send_node, variable_name)
          reads_variable?(send_node.receiver, variable_name)
        end

        def block_pass_calls
          parent_node.body.each_node(:block_pass).filter_map do |node|
            next if inside_nested_class?(node)

            node.children.first.value if node.children.first&.sym_type?
          end
        end

        def macro_referenced_methods
          @macro_referenced_methods ||= RuboCop::Callbacksystems::MacroReferencedMethods.for(nested_class.body).to_a
        end
    end
end
