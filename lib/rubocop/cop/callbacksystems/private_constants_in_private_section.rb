# A constant that only serves the implementation belongs in the private
# section, where every other implementation detail already lives. Marking it
# with `private_constant` from the top of the class says the same thing twice
# and leaves the declaration among the public ones.
#
# The marker earns its place when class-level code above needs the constant,
# since the declaration cannot move below the code that reads it.
#
# @example
#   # bad - only method bodies read it
#   class Backend
#     Route = Data.define(:host, :matcher)
#     private_constant :Route
#
#     def route_for(host)
#       Route.new(host, nil)
#     end
#   end
#
#   # good - declared where the implementation lives
#   class Backend
#     def route_for(host)
#       Route.new(host, nil)
#     end
#
#     private
#       Route = Data.define(:host, :matcher)
#   end
#
#   # good - class-level code reads it, so it has to stay above
#   class Backend
#     FORMATS = [ :json ].freeze
#     private_constant :FORMATS
#
#     validates :format, inclusion: { in: FORMATS }
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateConstantsInPrivateSection < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Declare `%<name>s` in the private section instead of marking it with `private_constant`."

  def on_send(node)
    PrivateConstantMarker.new(node).movable_arguments.each do |argument|
      add_offense(argument, message: format(MESSAGE, name: argument.value))
    end
  end

  alias on_csend on_send

  private
    class PrivateConstantMarker
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def movable_arguments
        marked_arguments.reject { read_at_class_level?(it) }
      end

      private
        attr_reader :node

        def marked_arguments
          marker? ? node.arguments.select { it.type?(:sym, :str) } : []
        end

        def marker?
          bare_send?(node) && node.method?(:private_constant)
        end

        def read_at_class_level?(argument)
          class_level_names.include?(argument.value.to_s)
        end

        # A constant read by class-level code has to be declared before that
        # code runs, so it cannot move down into the private section.
        def class_level_names
          constant_nodes.select { class_level_read?(it) }.map { it.short_name.to_s }
        end

        def constant_nodes
          enclosing_body ? enclosing_body.each_node(:const).to_a : []
        end

        def enclosing_body
          enclosing_class_or_module_of(node)&.body
        end

        def class_level_read?(constant)
          !inside_method?(constant) && !definition_identifier?(constant)
        end

        def inside_method?(constant)
          constant.each_ancestor(:any_def).any?
        end
    end
end
