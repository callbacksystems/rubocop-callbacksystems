# Detects an empty collection filled by hand inside an `each`. An empty array
# or hash assigned to a variable and then filled from a loop is a `map`,
# `select`, `filter_map`, `index_by` or `to_h` spread over two statements, so
# a reader has to run the loop in their head to learn what the collection
# holds, where the declarative call names it. The collection may be a local or
# an instance variable, and it need not be returned afterwards. The mutation
# may sit under `if`, `unless` or `case` branches, as long as every statement
# the body reaches is that mutation. A loop with any other statement, or one
# leaving through `next`, `break`, `return` or `raise`, is left alone, since
# the declarative form would drop that behavior.
#
# @example
#   # bad - array accumulation returned by the method
#   def names
#     results = []
#     items.each { |x| results << x.name }
#     results
#   end
#
#   # good - use map
#   def names
#     items.map { it.name }
#   end
#
#   # bad - array accumulation with a guard
#   results = []
#   items.each { |x| results << x.name if x.active? }
#
#   # good - use select or filter_map
#   results = items.filter_map { it.name if it.active? }
#
#   # bad - array filled by index
#   results = []
#   items.each_with_index { |x, index| results[index] = x.name }
#
#   # good - use map
#   results = items.map { it.name }
#
#   # bad - hash accumulation into an instance variable
#   @index = {}
#   items.each { |x| @index[x.id] = x }
#
#   # good - use index_by or to_h
#   @index = items.index_by { it.id }
#
class RuboCop::Cop::Callbacksystems::NoManualAccumulation < RuboCop::Cop::Callbacksystems::Base
  LOOP_METHODS = %i[ each each_with_index ]

  def on_block(node)
    report Accumulation.new(node) if LOOP_METHODS.include?(node.method_name)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    # A loop filling an empty collection that an earlier statement in the same list assigned.
    class Accumulation
      include RuboCop::Callbacksystems::Helpers

      MESSAGES = {
        array: "Don't fill an array with `%<loop>s`. Use `map`, `select` or `filter_map` instead.",
        hash: "Don't fill a hash with `%<loop>s`. Use `index_by` or `to_h` instead."
      }
      MUTATORS = { array: %i[ << push append []= store ], hash: %i[ []= store merge! ] }

      def initialize(loop_block)
        @loop_block = loop_block
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(loop_block.send_node, message) if accumulator && keeps_flow?
      end

      private
        attr_reader :loop_block
        delegate :body, to: :loop_block, private: true

        def accumulator
          @accumulator ||= empty_collection_assignments_before.find { fills?(it) }
        end

        def empty_collection_assignments_before
          preceding_statements.select { empty_collection_assignment?(it) && !reassigned_after?(it) }
        end

        def preceding_statements
          @preceding_statements ||= statements_before(loop_block)
        end

        def empty_collection_assignment?(statement)
          statement.type?(:lvasgn, :ivasgn) && empty_collection_literal?(statement.expression)
        end

        def reassigned_after?(assignment)
          preceding_statements.drop_while { !it.equal?(assignment) }.drop(1).any? do |statement|
            reassigned_within?(statement, assignment)
          end
        end

        def reassigned_within?(statement, assignment)
          RuboCop::Callbacksystems::Execution::Immediate.new(statement).nodes_of_type(assignment.type).any? do |node|
            node.name == assignment.name && !rebound_local?(node, assignment)
          end
        end

        def rebound_local?(candidate, assignment)
          assignment.lvasgn_type? &&
            name_rebound_between?(assignment.name, node: candidate, boundary: loop_block.parent)
        end

        # A statement beyond the mutation is a side effect `map` or `select` would drop, so such a loop is left alone.
        def fills?(assignment)
          leaves.any? && leaves.all? { mutation_of?(assignment, it) }
        end

        def leaves
          @leaves ||= Leaves.new(body).to_a
        end

        def mutation_of?(assignment, leaf)
          leaf.call_type? && reads_variable?(leaf.receiver, assignment.name) && mutator_of?(assignment, leaf)
        end

        def mutator_of?(assignment, call)
          MUTATORS[kind_of(assignment)].include?(call.method_name)
        end

        def kind_of(assignment)
          assignment.expression.type
        end

        def keeps_flow?
          RuboCop::Callbacksystems::Execution::Immediate.new(body).none? do |node|
            node.type?(:next, :break, :return) || raise?(node)
          end
        end

        def raise?(node)
          bare_send?(node) && node.method?(:raise)
        end

        def message
          format(MESSAGES[kind_of(accumulator)], loop: loop_block.method_name)
        end

        # Terminal statements reached through conditional branches, in the order the source presents them.
        class Leaves
          include Enumerable
          include RuboCop::Callbacksystems::Helpers

          def initialize(body)
            @body = body
          end

          def each
            if block_given?
              pending = statements_in(body).reverse
              until pending.empty?
                statement = pending.pop
                if branching?(statement)
                  branches_of(statement).reverse_each { pending.concat(statements_in(it).reverse) }
                else
                  yield statement
                end
              end
            else
              to_enum(__method__)
            end
          end

          private
            attr_reader :body

            def branching?(statement)
              statement.type?(:if, :case)
            end

            def branches_of(statement)
              if statement.if_type?
                [ statement.if_branch, statement.else_branch ]
              else
                [ *statement.when_branches.map(&:body), statement.else_branch ]
              end
            end
        end
    end
end
