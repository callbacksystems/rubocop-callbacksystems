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
    private_nested_classes(node).each do |nested_class|
      report_visibility_violations(node, nested_class)
    end
  end

  alias on_module on_class

  private
    def report_visibility_violations(node, nested_class)
      class_name = nested_class.identifier.short_name
      external_calls = ExternalCallCollector.new(node, nested_class, class_name).collect

      public_methods_in(nested_class).each do |method_node|
        next if external_calls.include?(method_node.method_name)

        add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: class_name))
      end
    end

    class ExternalCallCollector
      def initialize(parent_node, nested_class, class_name)
        @parent_node = parent_node
        @nested_class = nested_class
        @class_name = class_name
      end

      def collect
        @collect ||= Set.new([ :initialize ] + direct_calls + variable_calls + block_pass_calls + macro_referenced_methods)
      end

      private
        attr_reader :parent_node, :nested_class, :class_name

        def direct_calls
          external_sends.filter_map do |send_node|
            send_node.method_name if instance_method_call?(send_node.receiver)
          end
        end

        def variable_calls
          parent_node.body.each_node(:lvasgn).flat_map { calls_on_assigned_variable(it) }
        end

        def calls_on_assigned_variable(assignment)
          return [] unless instance_method_call?(assignment.children.second)

          variable_name = assignment.children.first
          external_sends.filter_map do |send_node|
            send_node.method_name if call_on_variable?(send_node, variable_name)
          end
        end

        def block_pass_calls
          parent_node.body.each_node(:block_pass).filter_map do |node|
            next if inside_nested_class?(node)

            node.children.first.value if node.children.first&.sym_type?
          end
        end

        def macro_referenced_methods
          return [] unless nested_class.body

          RuboCop::Callbacksystems::MacroReferencedMethods.new(nested_class.body).collect.to_a
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

        def call_on_variable?(send_node, variable_name)
          send_node.receiver&.lvar_type? && send_node.receiver.children.first == variable_name
        end
    end
end
