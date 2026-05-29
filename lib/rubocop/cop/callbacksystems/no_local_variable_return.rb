# Prohibits returning a local variable as the last statement of a method.
# Use `.tap`, `.then`, `each_with_object`, or return the expression directly instead.
#
# @example
#   # bad - returning a local variable
#   def process
#     result = calculate_something
#     result
#   end
#
#   # bad - assign, mutate, return
#   def process
#     result = []
#     result << item
#     result
#   end
#
#   # bad - explicit return of local variable
#   def process
#     result = {}
#     result[:key] = value
#     return result
#   end
#
#   # good - return the expression directly
#   def process
#     calculate_something
#   end
#
#   # good - use tap
#   def process
#     [].tap do |result|
#       result << item
#     end
#   end
#
#   # good - use each_with_object
#   def process
#     items.each_with_object([]) do |item, result|
#       result << transform(item)
#     end
#   end
#
#   # good - use then
#   def process
#     calculate_something.then do |result|
#       result.merge(extra: value)
#     end
#   end
#
#   # good - declarative approach
#   def process
#     [item]
#   end
#
class RuboCop::Cop::Callbacksystems::NoLocalVariableReturn < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Avoid returning a local variable. " \
    "Return the expression directly, or use `.tap`, `.then`, or `each_with_object`."

  def on_def(node)
    if (last = last_statement_in(node.body))
      returned = ReturnedLocal.new(last)
      add_offense(last, message: MESSAGE) { returned.inline(it) } if returned.local?
    end
  end

  alias on_defs on_def

  private
    # The method's final statement when it just hands back a local variable. Inlines
    # the value only when that variable is assigned immediately above and read just
    # once (here); mutation in between or any extra read is left for a human.
    class ReturnedLocal
      def initialize(node)
        @node = node
      end

      def local?
        variable&.lvar_type?
      end

      def inline(corrector)
        if inlineable?
          corrector.replace(node.source_range.with(begin_pos: assignment.source_range.begin_pos), replacement)
        end
      end

      private
        attr_reader :node

        def variable
          node.return_type? ? node.children.first : node
        end

        def inlineable?
          assignment && only_read_once?
        end

        def assignment
          previous = node.left_sibling
          previous if previous&.lvasgn_type? && previous.name == variable.name
        end

        def only_read_once?
          occurrences.one?(&:lvar_type?) && occurrences.one?(&:lvasgn_type?)
        end

        def occurrences
          @occurrences ||= scope.each_descendant(:lvar, :lvasgn).select { it.name == variable.name }
        end

        def scope
          node.each_ancestor(:any_def).first
        end

        def replacement
          node.return_type? ? "return #{assignment.expression.source}" : assignment.expression.source
        end
    end
end
