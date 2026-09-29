# A method you define goes in the private section, not above it with a
# `private :name` afterwards. The section already says what the marker repeats.
#
# The marker earns its place when the method is not defined here, since a
# section cannot reach a method that arrives from a superclass or a macro.
# `Data.define` generating readers you would rather hide is the usual case.
#
# @example
#   # bad
#   class Report
#     def total
#     end
#     private :total
#   end
#
#   # good
#   class Report
#     private
#       def total
#       end
#   end
#
#   # good - the reader comes from the superclass, so nothing here can hold it
#   class Request < Data.define(:lock_held)
#     alias lock_held? lock_held
#
#     private :lock_held
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateMethodsInPrivateSection < RuboCop::Cop::Callbacksystems::Base
  def on_send(node)
    report_each PrivateCall.new(node)
  end

  alias on_csend on_send

  private
    class PrivateCall
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Declare `%<name>s` in the private section instead of marking it with `private :%<name>s`."

      def initialize(node)
        @node = node
      end

      def each_offense
        movable_arguments.each { yield RuboCop::Callbacksystems::Offense.new(it, format(MESSAGE, name: it.value)) }
      end

      private
        attr_reader :node

        def movable_arguments
          names_marked_by(node, macro: :private).select { defined_here?(it) }
        end

        def defined_here?(argument)
          method_names.include?(argument.value.to_sym)
        end

        def method_names
          @method_names ||= direct_definitions_in(enclosing_body, :def).map(&:method_name)
        end

        def enclosing_body
          enclosing_definition_of(node)&.body
        end
    end
end
