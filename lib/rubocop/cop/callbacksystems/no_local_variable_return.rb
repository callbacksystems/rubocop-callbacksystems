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
      returned = ReturnedLocal.new(last, processed_source.comments)
      add_offense(last, message: MESSAGE) { returned.inline(it) } if returned.local?
    end
  end

  alias on_defs on_def

  private
    class ReturnedLocal
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def local?
        variable&.lvar_type?
      end

      # Two edits rather than one over the whole span, so a comment between them
      # survives and an explicit `return` stays where its author put it.
      def inline(corrector)
        if inlineable?
          corrector.remove(assignment_removal_range)
          corrector.replace(variable, assignment.expression.source)
        end
      end

      private
        attr_reader :node, :comments

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

        def assignment_removal_range
          range_ending_at_first_comment(assignment_gap, comments)
        end

        def assignment_gap
          assignment.source_range.with(end_pos: node.source_range.begin_pos)
        end
    end
end
