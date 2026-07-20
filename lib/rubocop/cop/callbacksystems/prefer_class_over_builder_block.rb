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

  MESSAGE = "Define `%<name>s` as a class instead of a block given to `%<builder>s`."

  def on_casgn(node)
    builder = BuilderBlock.new(node)
    add_offense(node, message: builder.offense_message) { builder.rewrite(it) } if builder.offense?
  end

  private
    class BuilderBlock
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        class_with_body?(node)
      end

      def offense_message
        format(MESSAGE, name: class_name_of(node), builder: builder_name)
      end

      # Only the `do ... end` form is rewritten. Anything else would need the
      # body moved onto its own lines to stay valid.
      def rewrite(corrector)
        corrector.replace(header, "class #{class_name_of(node)}#{inheritance}") if rewritable?
      end

      private
        attr_reader :node

        def builder_name
          "#{builder_call.receiver.source}.#{builder_call.method_name}"
        end

        def builder_call
          block.send_node
        end

        def block
          node.expression
        end

        def rewritable?
          block.multiline? && block.loc.begin.source == "do"
        end

        def header
          node.source_range.with(end_pos: block.loc.begin.end_pos)
        end

        # `Class.new(Base)` is a subclass of `Base` and nothing more, so the
        # definition inherits from `Base` itself. `Data.define` and `Struct.new`
        # build the class they are given, so the call stays the superclass.
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
