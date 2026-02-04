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
class RuboCop::Cop::Callbacksystems::PrivateNestedClassMethodVisibility < RuboCop::Cop::Base
  MESSAGE = "Method `%<method>s` in private nested class `%<class>s` is never called from outside. Make it private."

  def on_class(node)
    NestedClassAnalysis.new(node).unused_public_methods.each do |method_node, klass_name|
      add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: klass_name))
    end
  end

  alias on_module on_class

  private
    class NestedClassAnalysis
      attr_reader :node, :private_nested_classes

      def initialize(node)
        @node = node
        @private_nested_classes = find_private_nested_classes
      end

      def unused_public_methods
        private_nested_classes.flat_map do |nested_class|
          NestedClassMethods.new(nested_class, node).unused_public_methods
        end
      end

      private
        def find_private_nested_classes
          return [] unless node.body

          in_private = false
          node.body.each_child_node.select do |child|
            in_private = true if private_declaration?(child)
            in_private && child.class_type?
          end
        end

        def private_declaration?(child)
          child.send_type? && child.method_name == :private && child.arguments.empty?
        end
    end

    class NestedClassMethods
      def initialize(nested_class, parent_node)
        @nested_class = nested_class
        @parent_node = parent_node
        @class_name = nested_class.identifier.short_name
      end

      def unused_public_methods
        external = ExternalCallCollector.new(parent_node, nested_class, class_name).collect
        public_methods.filter_map do |method_node|
          [ method_node, class_name ] unless external.include?(method_node.method_name)
        end
      end

      private
        attr_reader :nested_class, :parent_node, :class_name

        def public_methods
          return [] unless nested_class.body

          in_private = false
          nested_class.body.each_child_node.select do |child|
            in_private = true if private_declaration?(child)
            child.def_type? && !in_private
          end
        end

        def private_declaration?(child)
          child.send_type? && child.method_name == :private && child.arguments.empty?
        end
    end

    class ExternalCallCollector
      def initialize(parent_node, nested_class, class_name)
        @parent_node = parent_node
        @nested_class = nested_class
        @class_name = class_name
      end

      def collect
        Set.new([ :initialize ] + direct_calls + variable_calls + macro_referenced_methods)
      end

      private
        attr_reader :parent_node, :nested_class, :class_name

        def direct_calls
          parent_node.body.each_node(:send).filter_map do |send_node|
            send_node.method_name if DirectCall.new(send_node, nested_class, class_name).match?
          end
        end

        def variable_calls
          parent_node.body.each_node(:lvasgn).flat_map do |assignment|
            VariableTracker.new(assignment, class_name, nested_class, parent_node).calls_on_variable
          end
        end

        def macro_referenced_methods
          return [] unless nested_class.body

          RuboCop::Callbacksystems::MacroReferencedMethods.new(nested_class.body).collect.to_a
        end
    end

    class DirectCall
      def initialize(send_node, nested_class, class_name)
        @send_node = send_node
        @nested_class = nested_class
        @class_name = class_name
      end

      def match?
        !inside_nested_class? && call_to_new_instance?
      end

      private
        attr_reader :send_node, :nested_class, :class_name

        def inside_nested_class?
          send_node.each_ancestor(:class).any?(nested_class)
        end

        def call_to_new_instance?
          send_node.receiver&.send_type? &&
            send_node.receiver.method_name == :new &&
            send_node.receiver.receiver&.const_type? &&
            send_node.receiver.receiver.short_name == class_name
        end
    end

    class VariableTracker
      attr_reader :assignment, :class_name, :nested_class, :parent_node, :variable_name

      def initialize(assignment, class_name, nested_class, parent_node)
        @assignment = assignment
        @class_name = class_name
        @nested_class = nested_class
        @parent_node = parent_node
        @variable_name = assignment.children.first
      end

      def calls_on_variable
        return [] unless assignment_creates_instance?

        parent_node.body.each_node(:send).filter_map do |send_node|
          send_node.method_name if VariableCall.new(send_node, variable_name, nested_class).match?
        end
      end

      private
        def assignment_creates_instance?
          value = assignment.children.second
          value&.send_type? &&
            value.method_name == :new &&
            value.receiver&.const_type? &&
            value.receiver.short_name == class_name
        end
    end

    class VariableCall
      def initialize(send_node, variable_name, nested_class)
        @send_node = send_node
        @variable_name = variable_name
        @nested_class = nested_class
      end

      def match?
        !inside_nested_class? && call_on_tracked_variable?
      end

      private
        attr_reader :send_node, :variable_name, :nested_class

        def inside_nested_class?
          send_node.each_ancestor(:class).any?(nested_class)
        end

        def call_on_tracked_variable?
          send_node.receiver&.lvar_type? && send_node.receiver.children.first == variable_name
        end
    end
end
