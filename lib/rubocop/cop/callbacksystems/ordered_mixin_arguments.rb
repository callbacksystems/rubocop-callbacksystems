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
class RuboCop::Cop::Callbacksystems::OrderedMixinArguments < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MIXIN_METHODS = %i[include extend prepend].freeze
  MESSAGE = "Sort mixin arguments alphabetically: `%<sorted>s`."

  def on_send(node)
    return unless mixin_call?(node) && node.arguments.many?

    names = node.arguments.map(&:source)
    sorted = names.sort
    add_offense(node, message: format(MESSAGE, sorted: sorted.join(", "))) { |corrector| correct_order(corrector, node, sorted) } if names != sorted
  end

  private
    def mixin_call?(node)
      node.receiver.nil? && MIXIN_METHODS.include?(node.method_name)
    end

    def correct_order(corrector, node, sorted)
      args = node.arguments
      corrector.replace(args.first.source_range.join(args.last.source_range), sorted.join(", "))
    end
end
