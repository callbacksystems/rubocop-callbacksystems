# Ensures the modules of one mixin call are sorted alphabetically.
#
# Putting several modules in one `include` is a claim that their order does not
# matter, and once that holds they may as well read alphabetically. When the
# order does matter, the modules belong on separate lines where the precedence
# is written down rather than implied. Separate calls are left alone: it is the
# comma that makes the claim, so only what shares one is sorted.
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
    mixin = MixinCall.new(node, processed_source.comments)
    add_offense(node, message: mixin.offense_message) { mixin.reorder(it) } if mixin.unsorted?
  end

  alias on_csend on_send

  private
    class MixinCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def unsorted?
        mixin_call? && node.arguments.many? && names != sorted_names
      end

      def offense_message
        format(MESSAGE, sorted: sorted_names.join(", "))
      end

      # Sorting rewrites the whole list in one go, and a comment written among
      # the modules was written about one of them: there is no telling which, so
      # a list carrying one is reported and left to be sorted by hand.
      def reorder(corrector)
        corrector.replace(arguments_range, sorted_names.join(", ")) unless holds_comment?(arguments_range, comments)
      end

      private
        attr_reader :node, :comments
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

        def arguments_range
          arguments.first.source_range.join(arguments.last.source_range)
        end
    end
end
