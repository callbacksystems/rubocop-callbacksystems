# Detects manual accumulation patterns that should use declarative methods.
# When you initialize an empty collection, iterate with each to fill it,
# and return it, use map, select, index_by, or to_h instead.
#
# @example
#   # bad - manual array accumulation
#   results = []
#   items.each { |x| results << x.name }
#   results
#
#   # good - use map
#   items.map { it.name }
#
#   # bad - manual hash accumulation
#   hash = {}
#   items.each { |x| hash[x.id] = x }
#   hash
#
#   # good - use index_by or to_h
#   items.index_by { it.id }
#
class RuboCop::Cop::Callbacksystems::NoManualAccumulation < RuboCop::Cop::Base
  MESSAGE = "Don't accumulate manually with `each`. Use `map`, `select`, `index_by`, or `to_h` instead."
  MUTATION_METHODS = %i[<< push append []= store].freeze

  # Matches: variable = [] or variable = {}
  def_node_matcher :empty_collection_assignment, <<~PATTERN
    (lvasgn $_variable_name {(array) (hash)})
  PATTERN

  # Matches: something.each { ... }
  def_node_matcher :each_block?, <<~PATTERN
    {(block (send _ :each) ...) (numblock (send _ :each) ...)}
  PATTERN

  # Matches: variable << x, variable.push(x), variable[k] = v, etc.
  def_node_matcher :mutates_variable?, <<~PATTERN
    (send (lvar %1) {:<< :push :append :[]= :store} ...)
  PATTERN

  # Matches: variable (as return value)
  def_node_matcher :variable_reference, <<~PATTERN
    (lvar $_name)
  PATTERN

  def on_def(node)
    check_body(node.body)
  end

  def on_block(node)
    check_body(node.body)
  end

  alias on_numblock on_block

  private
    def check_body(body)
      return unless body&.begin_type?

      body.children.each do |child|
        variable_name = empty_collection_assignment(child)
        next unless variable_name

        add_offense(child, message: MESSAGE) if accumulation_pattern?(body, child, variable_name)
      end
    end

    def accumulation_pattern?(body, assignment, variable_name)
      statements = statements_after(body, assignment)
      AccumulationStatements.new(statements, variable_name, self).accumulation_pattern?
    end

    def statements_after(body, assignment)
      index = body.children.index(assignment)
      body.children[(index + 1)..]
    end

    class AccumulationStatements
      attr_reader :statements, :variable_name, :cop

      def initialize(statements, variable_name, cop)
        @statements = statements
        @variable_name = variable_name
        @cop = cop
      end

      def accumulation_pattern?
        mutating_each? && returns_variable?
      end

      private
        def mutating_each?
          statements.any? { |statement| cop.send(:each_block?, statement) && mutates_in_body?(statement.body) }
        end

        def mutates_in_body?(body)
          body&.each_node(:send)&.any? { |send_node| cop.send(:mutates_variable?, send_node, variable_name) }
        end

        def returns_variable?
          cop.send(:variable_reference, statements.last) == variable_name
        end
    end
end
