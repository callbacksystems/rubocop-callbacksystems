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
class RuboCop::Cop::Callbacksystems::NestedClassesAtEndOfPrivateSection < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Method `%<method>s` should be defined before nested class `%<class>s`. Private nested classes should be at the end."

  def on_class(node)
    methods_after_first_class(node).each do |method_node, class_name|
      add_offense(method_node, message: format(MESSAGE, method: method_node.method_name, class: class_name))
    end
  end

  alias on_module on_class

  private
    def methods_after_first_class(node)
      children = each_child_with_visibility(node).filter_map { |child, in_private| child if in_private && child.type?(:def, :class) }
      first_class_index = children.index(&:class_type?)

      if first_class_index
        children.drop(first_class_index + 1).filter_map { [ it, children[first_class_index].identifier.short_name ] if it.def_type? }
      else
        []
      end
    end
end
