# A constant that only serves the implementation belongs in the private
# section, where every other implementation detail already lives. Marking it
# with `private_constant` from the top of the class says the same thing twice
# and leaves the declaration among the public ones.
#
# The marker earns its place when class-level code above the private section
# reads the constant, since the declaration cannot move below the code that
# reads it. Class-level code inside the section moves down with it.
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
#   # bad - the reader is private too, so both move
#   class Backend
#     MEMBERS = [ :host, :matcher ]
#     private_constant :MEMBERS
#
#     private
#       Route = Data.define(*MEMBERS)
#   end
#
#   # good
#   class Backend
#     private
#       MEMBERS = [ :host, :matcher ]
#       Route = Data.define(*MEMBERS)
#   end
#
#   # good - class-level code above reads it, so it has to stay there
#   class Backend
#     FORMATS = [ :json ]
#     private_constant :FORMATS
#
#     validates :format, inclusion: { in: FORMATS }
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateConstantsInPrivateSection < RuboCop::Cop::Callbacksystems::Base
  def on_send(node)
    report_each PrivateConstantMarker.new(node)
  end

  alias on_csend on_send

  private
    DEFERRED_MACROS = %i[ test setup teardown ]

    class PrivateConstantMarker
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Declare `%<name>s` in the private section instead of marking it with `private_constant`."
      REDUNDANT_MESSAGE = "Remove `private_constant` from `%<name>s`, which is already declared in the private section."

      def initialize(node)
        @node = node
      end

      def each_offense
        movable_arguments.each { yield RuboCop::Callbacksystems::Offense.new(it, message_for(it)) }
      end

      private
        attr_reader :node

        def movable_arguments
          enclosing_body ? names_marked_by(node, macro: :private_constant).reject { pinned?(it) } : []
        end

        def enclosing_body
          enclosing_class_or_module_of(node)&.body
        end

        def pinned?(argument)
          pinning_names.include?(argument.value.to_s)
        end

        def pinning_names
          @pinning_names ||= constant_reads.select(&:pins_declaration?).map(&:name)
        end

        def constant_reads
          constant_nodes.map { ConstantRead.new(it, enclosing_body) }
        end

        def constant_nodes
          nodes_in(enclosing_body, :const)
        end

        def message_for(argument)
          format(template_for(argument.value.to_sym), name: argument.value)
        end

        def template_for(name)
          declared_privately?(declaration_of(name)) ? REDUNDANT_MESSAGE : MESSAGE
        end

        def declared_privately?(declaration)
          declaration && in_private_section?(declaration, enclosing_body)
        end

        def declaration_of(name)
          statements_in(enclosing_body).find { declared_name_of(it) == name }
        end
    end

    # A read that would break if the declaration moved, made by class-level code above the private section.
    class ConstantRead
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, body)
        @node = node
        @body = body
      end

      def pins_declaration?
        own_constant? && class_level? && !in_private_section?(node, body)
      end

      def name
        node.short_name.to_s
      end

      private
        attr_reader :node, :body

        # `Other::Namespace::NAME` reads a constant of its own that happens to end in the same name.
        def own_constant?
          node.namespace.nil?
        end

        def class_level?
          !runs_later? && !definition_identifier?(node)
        end

        def runs_later?
          enclosing_method_of(node).present? || inside_deferred_block?
        end

        def inside_deferred_block?
          node.each_ancestor(:any_block).any? { DEFERRED_MACROS.include?(it.method_name) }
        end
    end
end
