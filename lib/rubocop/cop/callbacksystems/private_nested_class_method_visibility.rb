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
          @external_calls ||= Set.new([ :initialize ] + direct_calls + calls_on_instances + block_pass_calls + macro_referenced_methods)
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

        def calls_on_instances
          external_sends.filter_map { it.method_name if reads_instance?(it.receiver) }
        end

        def reads_instance?(receiver)
          instance_names.include?(name_read_by(receiver))
        end

        # A name bound to an instance: a variable assigned from the class, or a
        # method whose body evaluates to one. Calls on that name reach the class
        # from outside just as `Inner.new.run` does.
        def instance_names
          @instance_names ||= (assigned_names + returning_method_names).to_set
        end

        def assigned_names
          parent_node.body.each_node(:lvasgn, :ivasgn, :or_asgn).filter_map { it.name if instance_method_call?(it.expression) }
        end

        def returning_method_names
          direct_method_nodes_in(parent_node.body).filter_map { it.method_name if returns_instance?(it) }
        end

        def returns_instance?(method_node)
          instance_method_call?(returned_expression_in(method_node.body))
        end

        def returned_expression_in(body)
          body&.or_asgn_type? ? body.expression : body
        end

        def name_read_by(receiver)
          if receiver&.type?(:lvar, :ivar)
            receiver.name
          elsif bare_send?(receiver) && receiver.arguments.empty?
            receiver.method_name
          end
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
