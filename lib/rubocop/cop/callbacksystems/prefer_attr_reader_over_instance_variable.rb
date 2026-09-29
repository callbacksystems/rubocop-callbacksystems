# Detects direct use of instance variables that were assigned in initialize.
# Reading `@node` where `node` would do ties the method to how the value is
# stored, so a getter that later computes or memoizes it has to touch every
# reader. Behind an `attr_reader` the method reads the name and nothing else.
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
  def on_class(node)
    report_each InstanceVariableReads.new(node)
  end

  alias on_module on_class

  private
    class InstanceVariableReads
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Use `%<name>s` (via attr_reader) instead of `@%<name>s` for instance variables assigned in initialize."

      def initialize(class_node)
        @class_node = class_node
      end

      def each_offense
        reads_of_constructor_variables.each { yield offense_for(it) }
      end

      private
        attr_reader :class_node

        def reads_of_constructor_variables
          reads_outside_constructor.select { constructor_variable_names.include?(it.name) }
        end

        def reads_outside_constructor
          nodes_in(class_node.body, :ivar).select { instance_method_read?(it) }
        end

        def instance_method_read?(read)
          method = enclosing_method_of(read)
          method&.def_type? && direct_method_definition?(method) && !method.method?(:initialize) &&
            enclosing_class_or_module_of(read) == class_node && self_preserved_between?(read, boundary: method)
        end

        def constructor_variable_names
          @constructor_variable_names ||= nodes_in(initialize_method&.body, :ivasgn)
            .select { self_preserved_between?(it, boundary: initialize_method) }.to_set(&:name)
        end

        def initialize_method
          direct_method_nodes_in(class_node.body).find { it.method?(:initialize) }
        end

        def offense_for(read)
          RuboCop::Callbacksystems::Offense.new(read, format(MESSAGE, name: name_without_sigil(read.name)))
        end
    end
end
