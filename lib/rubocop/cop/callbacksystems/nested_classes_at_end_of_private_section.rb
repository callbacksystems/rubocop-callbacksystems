# Ensures private nested classes are defined at the end of the private section.
# Methods should not appear after nested class definitions.
#
# @example
#   # bad - method after nested class
#   class Foo
#     private
#       class Bar
#         # ...
#       end
#
#       def helper_method
#         # ...
#       end
#   end
#
#   # good - nested classes at the end
#   class Foo
#     private
#       def helper_method
#         # ...
#       end
#
#       class Bar
#         # ...
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::NestedClassesAtEndOfPrivateSection < RuboCop::Cop::Base
  MESSAGE = "Method `%<method>s` should be defined before nested class `%<class>s`. Private nested classes should be at the end."

  def on_class(node)
    PrivateSectionAnalysis.new(node).methods_after_classes.each do |method_node, class_name|
      add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: class_name))
    end
  end

  alias on_module on_class

  private
    class PrivateSectionAnalysis
      def initialize(node)
        @node = node
        @private_children = find_private_children
      end

      def methods_after_classes
        first_class_index = private_children.index(&:class_type?)
        methods_after_first_class(first_class_index)
      end

      private
        attr_reader :node, :private_children

        def methods_after_first_class(first_class_index)
          return [] unless first_class_index

          first_class_name = private_children[first_class_index].identifier.short_name
          private_children.drop(first_class_index + 1).filter_map do |child|
            [ child, first_class_name ] if child.def_type?
          end
        end

        def find_private_children
          return [] unless node.body

          in_private = false
          node.body.each_child_node.select do |child|
            in_private = true if private_declaration?(child)
            in_private && (child.def_type? || child.class_type?)
          end
        end

        def private_declaration?(child)
          child.send_type? && child.method_name == :private && child.arguments.empty?
        end
    end
end
