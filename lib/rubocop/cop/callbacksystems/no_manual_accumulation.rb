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
class RuboCop::Cop::Callbacksystems::NoManualAccumulation < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Don't accumulate manually with `each`. Use `map`, `select`, `index_by`, or `to_h` instead."

  # @!method empty_collection_assignment(node)
  def_node_matcher :empty_collection_assignment, <<~PATTERN
    (lvasgn $_variable_name {(array) (hash)})
  PATTERN

  def on_def(node)
    check_body(node.body)
  end

  alias on_defs on_def
  alias on_block on_def
  alias on_numblock on_def
  alias on_itblock on_def

  private
    def check_body(body)
      return unless body&.begin_type?

      body.children
        .select { empty_collection_assignment(it) }
        .each { add_offense(it, message: MESSAGE) if accumulation_pattern?(body, it, empty_collection_assignment(it)) }
    end

    def accumulation_pattern?(body, assignment, variable_name)
      AccumulationCheck.new(body.children[(body.children.index(assignment) + 1)..], variable_name).match?
    end

    class AccumulationCheck
      extend RuboCop::AST::NodePattern::Macros

      # @!method each_block?(node)
      def_node_matcher :each_block?, <<~PATTERN
        {(block (send _ :each) ...) (numblock (send _ :each) ...)}
      PATTERN

      # @!method mutates_variable?(node)
      def_node_matcher :mutates_variable?, <<~PATTERN
        (send (lvar %1) {:<< :push :append :[]= :store} ...)
      PATTERN

      # @!method variable_reference(node)
      def_node_matcher :variable_reference, <<~PATTERN
        (lvar $_name)
      PATTERN

      def initialize(statements, variable_name)
        @statements = statements
        @variable_name = variable_name
      end

      def match?
        mutating_each? && returns_variable?
      end

      private
        attr_reader :statements, :variable_name

        def mutating_each?
          statements.any? { each_block?(it) && mutates_in_body?(it.body) }
        end

        def mutates_in_body?(body)
          body&.each_node(:send)&.any? { mutates_variable?(it, variable_name) }
        end

        def returns_variable?
          variable_reference(statements.last) == variable_name
        end
    end
end
