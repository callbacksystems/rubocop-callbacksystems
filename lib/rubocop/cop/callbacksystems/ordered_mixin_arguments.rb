# Ensures mixin arguments on one line are sorted alphabetically.
#
# Putting several modules in one `include` is a claim that their order does not
# matter, and once that holds they may as well read alphabetically. When the
# order does matter, the modules belong on separate lines where the precedence
# is written down rather than implied.
#
# Ruby resolves `include A, B` to the ancestors `[A, B]` and `include B, A` to
# `[B, A]`, so sorting is only a rewrite of the appearance when no two modules
# define the same method. The cop cannot see the modules to know, which is why
# the correction is marked unsafe, so the unsafe autocorrect pass sorts and the
# safe one leaves it alone, and a collision is the case to split onto separate lines
# instead.
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
#   # good - separate lines, where the precedence is explicit
#   include Searchable
#   include Confirmable  # wins over Searchable, so it comes second
#
class RuboCop::Cop::Callbacksystems::OrderedMixinArguments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MIXIN_METHODS = %i[include extend prepend].freeze
  MESSAGE = "Sort mixin arguments alphabetically: `%<sorted>s`. If their order matters, put them on separate lines."

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
