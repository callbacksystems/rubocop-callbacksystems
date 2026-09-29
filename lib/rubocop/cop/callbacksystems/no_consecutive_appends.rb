# Detects consecutive appends to one collection. `list << a` followed by
# `list << b` makes the reader walk the same receiver twice, where a single
# `list.push(a, b)` states the whole addition at once.
#
# The run has to be adjacent statements on the same local variable, instance
# variable or bare method call, and none of the values may read or rebind the
# receiver, since `list << list.size` after an append counts what was pushed
# before it, while `list << (list = other)` changes what the next append reaches.
# `<<` also writes to a String, a Set or a stream, none of which takes several
# values through `push`, so the rule needs positive evidence that every visible
# assignment builds an Array and, for a local, an unconditional assignment above
# the run. An unknown receiver is left alone. A run carrying a comment or a
# heredoc is reported without a correction, since collapsing it would drop the
# comment or strand the heredoc body.
#
# @example
#   # bad
#   list = []
#   list << header
#   list << body
#
#   # bad
#   list = []
#   list.push(header)
#   list << body
#
#   # good
#   list = []
#   list.push(header, body)
#
#   # good - the second value reads the receiver
#   list = []
#   list << header
#   list << list.size
#
class RuboCop::Cop::Callbacksystems::NoConsecutiveAppends < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @assigned_values = AssignedValues.new(processed_source.ast)
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
  end

  def on_begin(node)
    report_each AppendRuns.new(node, assigned_values:, source_comments:)
  end

  alias on_kwbegin on_begin

  private
    attr_reader :assigned_values, :source_comments

    # The runs of adjacent appends to one receiver inside a statement list.
    class AppendRuns
      def initialize(statement_list, assigned_values:, source_comments:)
        @statement_list = statement_list
        @assignment_index = assigned_values
        @source_comments = source_comments
      end

      def each_offense
        runs.select(&:array_receiver?).each { yield it.offense }
      end

      private
        attr_reader :statement_list, :assignment_index, :source_comments

        def runs
          appends.chunk_while { |left, right| left.continued_by?(right) }.select(&:many?).map { run_of(it) }
        end

        def appends
          statement_list.children.map { Append.new(it) }
        end

        def run_of(members)
          Run.new(members, assigned_values: assignment_index, source_comments:)
        end
    end

    # One statement read as an append, or as the statement that ends a run.
    class Append
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      attr_reader :node

      # @!method appended(node)
      def_node_matcher :appended, <<~PATTERN
        (send ${lvar ivar (send nil? _)} {:<< :push} $!block_pass+)
      PATTERN

      def initialize(node)
        @node = node
      end

      def continued_by?(other)
        append? && other.append? && receiver.source == other.receiver.source
      end

      def append?
        captures.present? && !touches_receiver?
      end

      def receiver
        captures.first
      end

      def values
        captures.second
      end

      private
        def captures
          @captures ||= appended(node)
        end

        def touches_receiver?
          values.any? { |value| nodes_in(value, *receiver_node_types).any? { same_receiver?(it) } }
        end

        def receiver_node_types
          if receiver.lvar_type? then %i[ lvar lvasgn match_var ]
          elsif receiver.ivar_type? then %i[ ivar ivasgn ]
          else [ receiver.type ]
          end
        end

        def same_receiver?(occurrence)
          if receiver.lvar_type?
            variable_name_of(occurrence) == receiver.name &&
              !name_rebound_between?(receiver.name, node: occurrence, boundary: scope)
          elsif receiver.ivar_type?
            occurrence.name == receiver.name
          else
            occurrence.source == receiver.source
          end
        end

        def scope
          @scope ||= enclosing_scope_of(node)
        end
    end

    class Run
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Append `%<values>s` to `%<receiver>s` in one `push` instead of consecutive appends."

      def initialize(appends, assigned_values:, source_comments:)
        @appends = appends
        @assignment_index = assigned_values
        @source_comments = source_comments
      end

      def array_receiver?
        assigned_values.any? && assigned_values.all? { array_value?(it) } && initialized_before_run?
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(range, message, correcting: rewritable?) { correct(it) }
      end

      private
        attr_reader :appends, :assignment_index, :source_comments
        delegate :receiver, to: "appends.first", private: true

        def assigned_values
          @assigned_values ||= assignments.map { assigned_value_of(it) unless it.match_var_type? }
        end

        def assignments
          assignment_index.for(receiver)
        end

        def assigned_value_of(assignment)
          assignment.parent.or_asgn_type? ? assignment.parent.expression : assignment.expression
        end

        def array_value?(value)
          reads_as_array?(value)
        end

        def initialized_before_run?
          !receiver.lvar_type? || assignments.any? { direct_assignment_before_run?(it) }
        end

        def direct_assignment_before_run?(assignment)
          assignment.parent.equal?(appends.first.node.parent) &&
            assignment.source_range.begin_pos < appends.first.node.source_range.begin_pos
        end

        def range
          range_spanning(appends.map(&:node))
        end

        def message
          format(MESSAGE, values: values.map(&:source).join(", "), receiver: receiver.source)
        end

        def values
          appends.flat_map(&:values)
        end

        def rewritable?
          !receiver.send_type? && !commented? && appends.none? { carries_heredoc?(it.node) }
        end

        def commented?
          source_comments.any_on_lines?(range.first_line..range.last_line)
        end

        def correct(corrector)
          corrector.replace(range, "#{receiver.source}.push(#{values.map(&:source).join(", ")})")
        end
    end

    # Assignments grouped once by local lexical scope or by instance-variable name for the whole file.
    class AssignedValues
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast)
        @ast = ast
        @local_variables = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      end

      def for(receiver)
        if receiver.lvar_type?
          local_variables.named(receiver.name, around: receiver).select { it.type?(:lvasgn, :match_var) }
        else
          instance_assignments.fetch(instance_variable_key_of(receiver)) { [] }
        end
      end

      private
        attr_reader :ast, :local_variables

        def instance_assignments
          @instance_assignments ||= nodes_in(ast, :ivasgn).select { state_belongs_to_domain?(it) }
            .group_by { instance_variable_key_of(it) }
        end

        def state_belongs_to_domain?(assignment)
          self_preserved_between?(assignment, boundary: state_boundary_of(assignment))
        end

        def state_boundary_of(assignment)
          enclosing_method_of(assignment) || RuboCop::Callbacksystems::Methods::Domain.new(assignment).container
        end

        def instance_variable_key_of(node)
          domain = RuboCop::Callbacksystems::Methods::Domain.new(node)

          [ instance_variable_name_of(node), domain.container&.object_id, domain.identity ]
        end

        def instance_variable_name_of(receiver)
          receiver.send_type? ? :"@#{receiver.method_name}" : receiver.name
        end
    end
end
