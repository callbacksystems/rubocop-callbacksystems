# Ensures mixin arguments are sorted alphabetically.
#
# When including, extending, or prepending multiple modules on the same line,
# they should be sorted alphabetically for consistency and easier scanning.
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

  MIXIN_METHODS = %i[include extend prepend].freeze
  MESSAGE = "Sort mixin arguments alphabetically: `%<sorted>s`."

  def on_send(node)
    mixin = MixinCall.new(node)
    add_offense(node, message: mixin.offense_message) { mixin.reorder(it) } if mixin.unsorted?
  end

  alias on_csend on_send

  private
    class MixinCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def unsorted?
        mixin_call? && node.arguments.many? && names != sorted_names
      end

      def offense_message
        format(MESSAGE, sorted: sorted_names.join(", "))
      end

      def reorder(corrector)
        corrector.replace(arguments.first.source_range.join(arguments.last.source_range), sorted_names.join(", "))
      end

      private
        attr_reader :node
        delegate :arguments, to: :node, private: true

        def mixin_call?
          bare_send?(node) && MIXIN_METHODS.include?(node.method_name)
        end

        def names
          @names ||= arguments.map(&:source)
        end

        def sorted_names
          @sorted_names ||= names.sort
        end
    end
end
