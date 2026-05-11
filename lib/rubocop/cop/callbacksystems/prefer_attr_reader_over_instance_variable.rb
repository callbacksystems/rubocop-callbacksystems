# Detects direct use of instance variables that were assigned in initialize.
# If an instance variable is set in initialize, access it via attr_reader instead.
#
# This cop only applies to instance variables assigned in the constructor.
# Instance variables assigned elsewhere (like in controllers) are not flagged.
#
# @example
#   # bad - using @node directly when it was set in initialize
#   class Foo
#     def initialize(node)
#       @node = node
#     end
#
#     def process
#       @node.children
#     end
#   end
#
#   # good - using attr_reader
#   class Foo
#     def initialize(node)
#       @node = node
#     end
#
#     def process
#       node.children
#     end
#
#     private
#       attr_reader :node
#   end
#
class RuboCop::Cop::Callbacksystems::PreferAttrReaderOverInstanceVariable < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Use `%<name>s` (via attr_reader) instead of `@%<name>s` for instance variables assigned in initialize."

  def on_class(node)
    ClassAnalysis.new(node).direct_ivar_usages.each do |ivar_node, name|
      add_offense(ivar_node, message: format(MESSAGE, name: name))
    end
  end

  private
    class ClassAnalysis
      include RuboCop::Callbacksystems::Helpers

      def initialize(class_node)
        @class_node = class_node
        @constructor_ivars = find_constructor_ivars
      end

      def direct_ivar_usages
        return [] if constructor_ivars.empty?

        ivar_reads_outside_constructor.filter_map do |ivar_node|
          name = ivar_node.children.first.to_s.delete_prefix("@")
          [ ivar_node, name ] if constructor_ivars.include?(name)
        end
      end

      private
        attr_reader :class_node, :constructor_ivars

        def find_constructor_ivars
          return Set.new unless initialize_method&.body

          initialize_method.body.each_node(:ivasgn).to_set { it.children.first.to_s.delete_prefix("@") }
        end

        def initialize_method
          @initialize_method ||= class_node.body&.each_node(:def)&.find do |method|
            method.method?(:initialize) && direct_child_of_class?(method, class_node)
          end
        end

        def ivar_reads_outside_constructor
          return [] unless class_node.body

          class_node.body.each_node(:ivar).select do |ivar_node|
            IvarRead.new(ivar_node, class_node).outside_constructor_and_nested_scopes?
          end
        end
    end

    class IvarRead
      def initialize(ivar_node, class_node)
        @ivar_node = ivar_node
        @class_node = class_node
      end

      def outside_constructor_and_nested_scopes?
        !inside_initialize? && !inside_nested_scope?
      end

      private
        attr_reader :ivar_node, :class_node

        def inside_initialize?
          ivar_node.each_ancestor(:def).any? { it.method?(:initialize) }
        end

        def inside_nested_scope?
          immediate_scope = ivar_node.each_ancestor(:class, :module).first
          immediate_scope && immediate_scope != class_node
        end
    end
end
