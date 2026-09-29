# Prohibits returning a local variable as the last statement of a method. The
# variable is a name for the value the method already hands back, so the last
# line reads as a summary of the ones above it, and the whole body is a
# `tap`, a `then` or an `each_with_object` spelled out by hand.
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

  def on_def(node)
    last_statement_in(node.body)&.then do |statement|
      report ReturnedLocal.new(statement, source_comments: RuboCop::Callbacksystems::Source::Comments.for(processed_source))
    end
  end

  alias on_defs on_def

  private
    class ReturnedLocal
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Avoid returning a local variable. " \
        "Return the expression directly, or use `.tap`, `.then`, or `each_with_object`."
      SCOPE_REFLECTION_METHODS = %i[ binding eval local_variables ]

      def initialize(node, source_comments:)
        @node = node
        @source_comments = source_comments
      end

      def offense
        if variable&.lvar_type? && assigned?
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: inlineable?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_comments

        def variable
          @variable ||= returned_expression_of(node)
        end

        # A parameter handed back as it came is not a value computed and then returned.
        def assigned?
          occurrences.any? { it.type?(:lvasgn, :match_var) }
        end

        def occurrences
          @occurrences ||= RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(method_node)
            .named_in_method(variable.name, around: node)
        end

        def method_node
          @method_node ||= enclosing_method_of(node)
        end

        # A heredoc keeps its body on the lines past the assignment, so inlining the opener would leave the body behind.
        def inlineable?
          assignment && only_read_once? && scope_preserved? && source_preserved?
        end

        def assignment
          @assignment ||= statements_before(node).last(1).find { it.lvasgn_type? && it.name == variable.name }
        end

        def only_read_once?
          occurrences.one?(&:lvar_type?) && occurrences.one?(&:lvasgn_type?) && occurrences.none?(&:match_var_type?)
        end

        def scope_preserved?
          !captured_by_deferred_callable? && !reflects_on_local_scope?
        end

        def captured_by_deferred_callable?
          RuboCop::Callbacksystems::Execution::DeferredLocalVariables.new(method_node.body).include?(variable.name)
        end

        # Removing the assignment removes its name from bindings even when Ruby source never reads that name directly.
        def reflects_on_local_scope?
          nodes_in(method_node.body, :send, :csend).any? do |call|
            SCOPE_REFLECTION_METHODS.include?(call.method_name) && scope_reader?(call)
          end
        end

        def scope_reader?(call)
          call_on_self?(call) || (core_constant?(call.receiver) && call.receiver.short_name == :Kernel)
        end

        def source_preserved?
          !carries_heredoc?(assignment.expression) && !reads_source_line? && !moves_tooling_comment? &&
            !assignment_trailing_comment?
        end

        def reads_source_line?
          assignment.expression.source.include?("__LINE__")
        end

        def moves_tooling_comment?
          source_comments.tooling_within?(assignment.source_range.join(node.source_range))
        end

        def assignment_trailing_comment?
          source_comments.trailing_comment_on(assignment.last_line).present?
        end

        def correct(corrector)
          corrector.remove(assignment_removal_range)
          corrector.replace(node, replacement)
        end

        def assignment_removal_range
          inline_statement_removal_range_for(assignment) ||
            blank_line_below(line_removal_range_for(assignment)) ||
            line_removal_range_for(assignment)
        end

        def replacement
          node.return_type? ? "return #{assignment.expression.source}" : assignment.expression.source
        end
    end
end
