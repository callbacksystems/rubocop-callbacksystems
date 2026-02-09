# Detects unused private methods in private nested classes.
# Since the nested class is private, no external code can inherit from it,
# so we can detect unused private methods within the same file.
#
# @example
#   # bad - unused private method
#   class Foo
#     def process
#       Bar.new.run
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
class RuboCop::Cop::Callbacksystems::UnusedPrivateMethodInNestedClass < RuboCop::Cop::Base
  MESSAGE = "Private method `%<method>s` in nested class `%<class>s` is never called. Remove it."

  def on_class(node)
    NestedClassAnalysis.new(node).unused_private_methods.each do |method_node, klass_name|
      add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: klass_name))
    end
  end

  alias on_module on_class

  private
    class NestedClassAnalysis
      def initialize(node)
        @node = node
        @private_nested_classes = find_private_nested_classes
      end

      def unused_private_methods
        private_nested_classes.flat_map do |nested_class|
          NestedClassMethods.new(nested_class).unused_private_methods
        end
      end

      private
        attr_reader :node, :private_nested_classes

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
      def initialize(nested_class)
        @nested_class = nested_class
        @class_name = nested_class.identifier.short_name
      end

      def unused_private_methods
        called_methods = collect_called_methods
        macro_methods = collect_macro_referenced_methods

        private_methods.filter_map do |method_node|
          method_name = method_node.method_name
          [ method_node, class_name ] if called_methods.exclude?(method_name) && macro_methods.exclude?(method_name)
        end
      end

      private
        attr_reader :nested_class, :class_name

        def private_methods
          return [] unless nested_class.body

          in_private = false
          nested_class.body.each_child_node.select do |child|
            in_private = true if private_declaration?(child)
            child.def_type? && in_private
          end
        end

        def collect_called_methods
          return Set.new unless nested_class.body

          Set.new(
            nested_class.body.each_node(:send).filter_map do |send_node|
              send_node.method_name if send_node.receiver.nil?
            end
          )
        end

        def collect_macro_referenced_methods
          return Set.new unless nested_class.body

          RuboCop::Callbacksystems::MacroReferencedMethods.new(nested_class.body).collect
        end

        def private_declaration?(child)
          child.send_type? && child.method_name == :private && child.arguments.empty?
        end
    end
end
