# Detects array access with numeric indices that could use ordinal methods.
# `items.second` says which element it wants, where `items[1]` makes the
# reader count from zero.
#
# `[]` answers for a Hash, a MatchData and a String too, and the ordinal methods
# come from Array alone, so a receiver we can read as one of those is left alone.
# That includes a receiver read out of another `[]`, whose type the file never
# shows, and a local variable whose assignment in the same scope hands it one of
# those.
#
# @example
#   # bad
#   items[1]
#   items[2]
#   items[3]
#   items[4]
#   items[-2]
#   items[-3]
#
#   # good
#   items.second
#   items.third
#   items.fourth
#   items.fifth
#   items.second_to_last
#   items.third_to_last
#
class RuboCop::Cop::Callbacksystems::PreferOrdinalArrayAccess < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @local_variables = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(processed_source.ast)
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
  end

  def on_send(node)
    report IndexedRead.new(node, @local_variables, @source_comments)
  end

  alias on_csend on_send

  private
    ORDINAL_METHODS = {
      1 => :second,
      2 => :third,
      3 => :fourth,
      4 => :fifth,
      -2 => :second_to_last,
      -3 => :third_to_last
    }

    NON_ARRAY_LITERAL_TYPES = %i[ dsym hash int regexp sym ]
    # `[]` reads out of anything, `match` and its friends answer a MatchData, and the rest answer a Hash.
    NON_ARRAY_RESULT_METHODS = %i[
      [] last_match match match? named_captures to_h to_hash group_by index_by index_with tally params
    ]

    # One `items[1]`, offending when an ordinal method names that position and nothing says the receiver is no array.
    class IndexedRead
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      MESSAGE = "Use `%<method>s` instead of `[%<index>s]`."

      # @!method bracket_access_with_int?(node)
      def_node_matcher :bracket_access_with_int?, <<~PATTERN
        (call $_ :[] (int $_index))
      PATTERN

      def initialize(node, local_variables, source_comments)
        @node = node
        @local_variables = local_variables
        @source_comments = source_comments
      end

      def offense
        if ordinal_method && array_receiver?
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: correction_keeps_comments?) { correct(it) }
        end
      end

      private
        attr_reader :node, :local_variables, :source_comments

        def ordinal_method
          ORDINAL_METHODS[index] if captures
        end

        def captures
          @captures ||= bracket_access_with_int?(node)
        end

        def index
          captures.second
        end

        def array_receiver?
          !non_array_value?(receiver) && !assigned_a_non_array?
        end

        def non_array_value?(value)
          reads_as_string?(value) ||
            reads_as?(value, literals: NON_ARRAY_LITERAL_TYPES, methods: NON_ARRAY_RESULT_METHODS)
        end

        def receiver
          captures.first
        end

        def assigned_a_non_array?
          receiver.lvar_type? && assignments.any? do |assignment|
            assignment.match_var_type? || assignment.expression.nil? || non_array_value?(assignment.expression)
          end
        end

        def assignments
          local_variables.named(receiver.name, around: receiver).select { it.type?(:lvasgn, :match_var) }
        end

        def message
          format(MESSAGE, method: ordinal_method, index: index)
        end

        def correction_keeps_comments?
          !source_comments.any_within?(node)
        end

        def correct(corrector)
          corrector.replace(node, "#{receiver.source}#{call_operator}#{ordinal_method}")
        end

        def call_operator
          node.csend_type? ? "&." : "."
        end
    end
end
