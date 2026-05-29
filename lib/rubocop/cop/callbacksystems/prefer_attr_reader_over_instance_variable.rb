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
    ClassAnalysis.new(node).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class

  private
    class ClassAnalysis
      include RuboCop::Callbacksystems::Helpers

      def initialize(class_node)
        @class_node = class_node
      end

      def each_offense(&block)
        if block
          direct_ivar_usages.each { |ivar_node, name| yield ivar_node, format(MESSAGE, name: name) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :class_node

        def direct_ivar_usages
          return [] if constructor_ivars.empty?

          ivar_reads_outside_constructor.filter_map do |ivar_node|
            [ ivar_node, ivar_node.name.to_s.delete_prefix("@") ] if constructor_ivars.include?(ivar_node.name)
          end
        end

        def constructor_ivars
          @constructor_ivars ||=
            if initialize_method&.body
              initialize_method.body.each_node(:ivasgn).to_set(&:name)
            else
              Set.new
            end
        end

        def initialize_method
          @initialize_method ||= direct_method_nodes_in(class_node.body).find { it.method?(:initialize) }
        end

        def ivar_reads_outside_constructor
          if class_node.body
            class_node.body.each_node(:ivar).select do |ivar_node|
              IvarRead.new(ivar_node, class_node).outside_constructor_and_nested_scopes?
            end
          else
            []
          end
        end
    end

    class IvarRead
      include RuboCop::Callbacksystems::Helpers

      def initialize(ivar_node, class_node)
        @ivar_node = ivar_node
        @class_node = class_node
      end

      def outside_constructor_and_nested_scopes?
        !inside_initialize?(ivar_node) && !inside_nested_scope?
      end

      private
        attr_reader :ivar_node, :class_node

        def inside_nested_scope?
          immediate_scope = enclosing_class_or_module_of(ivar_node)
          immediate_scope && immediate_scope != class_node
        end
    end
end
