# Ensures mixin arguments are sorted alphabetically.
#
# When including, extending, or prepending multiple modules on the same line,
# they should be sorted alphabetically for consistency and easier scanning.
#
# The order of one `include` decides which module wins when two define the same
# method, so sorting can change what the class does. The fix runs under `-A`
# rather than `-a` for that reason. Write the modules on separate lines when the
# order between them matters.
#
# @example
#   # bad - unsorted
#   include Searchable, Confirmable, Accessible
#
#   # good - sorted alphabetically
#   include Accessible, Confirmable, Searchable
#
#   # good - single module (nothing to sort)
#   include Searchable
#
#   # good - separate lines (each line is independent)
#   include Searchable
#   include Confirmable  # depends on Searchable
#
class RuboCop::Cop::Callbacksystems::OrderedMixinArguments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report MixinCall.new(node, processed_source)
  end

  alias on_csend on_send

  private
    class MixinCall
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Sort mixin arguments alphabetically: `%<sorted>s`."

      def initialize(node, processed_source)
        @node = node
        @processed_source = processed_source
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message, correcting: uncommented?) { correct(it) } if unsorted?
      end

      private
        attr_reader :node, :processed_source
        delegate :arguments, to: :node, private: true

        def unsorted?
          mixin_macro?(node) && arguments.many? && names != sorted_names
        end

        def names
          @names ||= arguments.map(&:source)
        end

        def sorted_names
          @sorted_names ||= names.sort
        end

        def message
          format(MESSAGE, sorted: sorted_names.join(", "))
        end

        # Once arguments move, a comment on their lines no longer names the element or precedence it was written for.
        def uncommented?
          processed_source.comments.none? { it.loc.line.between?(node.first_line, node.last_line) }
        end

        def correct(corrector)
          corrector.replace(range_spanning(arguments), sorted_names.join(", "))
        end
    end
end
