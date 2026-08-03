# A method you define goes in the private section, not above it with a `private :name` afterwards. The section already
# says what the marker repeats.
#
# The marker earns its place when the method is not defined here, since a section cannot reach a method that arrives
# from a superclass or a macro. `Data.define` generating readers you would rather hide is the usual case.
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
  MESSAGE = "Declare `%<name>s` in the private section instead of marking it with `private :%<name>s`."

  def on_send(node)
    PrivateCall.new(node).movable_arguments.each do |argument|
      add_offense(argument, message: format(MESSAGE, name: argument.value))
    end
  end

  alias on_csend on_send

  private
    class PrivateCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def movable_arguments
        marked_arguments.select { defined_here?(it) }
      end

      private
        attr_reader :node

        def marked_arguments
          marker? ? node.arguments.select { it.type?(:sym, :str) } : []
        end

        def marker?
          bare_send?(node) && node.method?(:private)
        end

        def defined_here?(argument)
          method_names.include?(argument.value.to_sym)
        end

        def method_names
          @method_names ||= statements_in(enclosing_body).select(&:def_type?).map(&:method_name)
        end

        def enclosing_body
          enclosing_class_or_module_of(node)&.body
        end
    end
end
