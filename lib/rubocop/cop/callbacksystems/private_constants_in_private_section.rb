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
#     MEMBERS = [ :host, :matcher ].freeze
#     private_constant :MEMBERS
#
#     private
#       Route = Data.define(*MEMBERS)
#   end
#
#   # good
#   class Backend
#     private
#       MEMBERS = [ :host, :matcher ].freeze
#       Route = Data.define(*MEMBERS)
#   end
#
#   # good - class-level code above reads it, so it has to stay there
#   class Backend
#     FORMATS = [ :json ].freeze
#     private_constant :FORMATS
#
#     validates :format, inclusion: { in: FORMATS }
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateConstantsInPrivateSection < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Declare `%<name>s` in the private section instead of marking it with `private_constant`."
  REDUNDANT_MESSAGE = "Remove `private_constant` from `%<name>s`, which is already declared in the private section."

  def on_send(node)
    PrivateConstantMarker.new(node).each_offense do |argument, message|
      add_offense(argument, message: message)
    end
  end

  alias on_csend on_send

  private
    class PrivateConstantMarker
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def each_offense(&block)
        if block
          movable_arguments.each { yield it, message_for(it) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node

        def movable_arguments
          marked_arguments.reject { pinned?(it) }
        end

        def marked_arguments
          marker? ? node.arguments.select { it.type?(:sym, :str) } : []
        end

        def marker?
          bare_send?(node) && node.method?(:private_constant)
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
          enclosing_body ? enclosing_body.each_node(:const).to_a : []
        end

        def enclosing_body
          enclosing_class_or_module_of(node)&.body
        end

        def message_for(argument)
          format(template_for(argument.value.to_s), name: argument.value)
        end

        # The marker on a constant already sitting in the private section says
        # nothing the section does not.
        def template_for(name)
          declared_privately?(declaration_of(name)) ? REDUNDANT_MESSAGE : MESSAGE
        end

        def declared_privately?(declaration)
          declaration && in_private_section?(declaration, enclosing_body)
        end

        def declaration_of(name)
          statements_in(enclosing_body).find { declared_name_of(it) == name }
        end

        def declared_name_of(statement)
          case statement.type
          when :casgn then statement.name.to_s
          when :class, :module then statement.identifier.short_name.to_s
          end
        end
    end

    # A constant read that would break if the declaration moved: one made by
    # class-level code, from above the private section the declaration would
    # move into.
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

        # `Other::Namespace::NAME` reads a constant of its own that happens to
        # end in the same name.
        def own_constant?
          node.namespace.nil?
        end

        def class_level?
          !inside_method? && !definition_identifier?(node)
        end

        def inside_method?
          node.each_ancestor(:any_def).any?
        end
    end
end
