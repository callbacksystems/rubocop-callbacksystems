# A `Data.define`, `Struct.new` or `Class.new` given a block defines a class
# with behavior, so it reads better as the class it is.
#
# The block form also changes what the code inside it means. A constant
# declared there lands in the enclosing namespace instead of the new class,
# `Module.nesting` never mentions the class, and the rules that govern a class
# body do not reach inside a block.
#
# A builder with no block only lists its members and stays as it is.
#
# @example
#   # bad
#   Route = Data.define(:host) do
#     def matches?(other)
#       host == other
#     end
#   end
#
#   # good
#   class Route < Data.define(:host)
#     def matches?(other)
#       host == other
#     end
#   end
#
#   # good - nothing but its members
#   Entry = Data.define(:sku, :quantity)
#
class RuboCop::Cop::Callbacksystems::PreferClassOverBuilderBlock < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_casgn(node)
    report BuilderBlock.new(node)
  end

  private
    class BuilderBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Define `%<name>s` as a class instead of a block given to `%<builder>s`."

      def initialize(node)
        @node = node
      end

      def offense
        if class_with_body?(node)
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: rewritable?) { correct(it) }
        end
      end

      private
        attr_reader :node

        def message
          format(MESSAGE, name: assigned_name, builder: builder_name)
        end

        def assigned_name
          node.source_range.with(end_pos: node.loc.operator.begin_pos).source.rstrip
        end

        def builder_name
          "#{builder_call.receiver.source}.#{builder_call.method_name}"
        end

        def builder_call
          block.send_node
        end

        def block
          node.expression
        end

        # Only `do ... end` is rewritten, since anything else needs the body moved onto its own lines to stay valid.
        def rewritable?
          block.multiline? && block.loc.begin.source == "do" && block.argument_list.empty? &&
            !captures_local_variable? && !reads_or_assigns_constant? && !reads_or_assigns_class_variable? &&
            !builder_control_flow?
        end

        def captures_local_variable?
          nodes_in(block.body, :lvar).any? do |read|
            read.each_ancestor(:any_def).none? &&
              !name_rebound_between?(read.name, node: read, boundary: block)
          end
        end

        def reads_or_assigns_constant?
          nodes_in(block.body, :const, :casgn).any?
        end

        def reads_or_assigns_class_variable?
          nodes_in(block.body, :cvar, :cvasgn).any?
        end

        def builder_control_flow?
          nodes_in(block.body, :break, :next, :redo).any? do |flow|
            flow.each_ancestor(*BLOCK_NODE_TYPES).first.equal?(block)
          end
        end

        def correct(corrector)
          corrector.replace(header, "class #{assigned_name}#{inheritance}")
        end

        def header
          node.source_range.with(end_pos: block.loc.begin.end_pos)
        end

        # `Class.new(Base)` is a plain subclass of `Base`, while `Data.define` and `Struct.new` build the superclass.
        def inheritance
          plain_subclass? ? argument_inheritance : " < #{builder_call.source}"
        end

        def plain_subclass?
          builder_call.receiver.short_name == :Class
        end

        def argument_inheritance
          " < #{builder_call.first_argument.source}" if builder_call.first_argument
        end
    end
end
