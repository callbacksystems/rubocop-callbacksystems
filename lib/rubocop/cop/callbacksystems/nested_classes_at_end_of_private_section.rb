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
    PrivateSectionLayout.new(node).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class

  private
    class PrivateSectionLayout
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def each_offense(&block)
        if block
          misplaced_methods.each { yield it, format(MESSAGE, method: it.method_name, class: first_class.identifier.short_name) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node

        def misplaced_methods
          if first_class
            private_members.drop(private_members.index(first_class) + 1).select(&:def_type?)
          else
            []
          end
        end

        def first_class
          @first_class ||= private_members.find(&:class_type?)
        end

        def private_members
          @private_members ||= each_child_with_visibility(node).filter_map do |child, in_private|
            child if in_private && child.type?(:def, :class)
          end
        end
    end
end
