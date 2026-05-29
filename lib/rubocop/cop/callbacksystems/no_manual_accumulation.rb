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
    each_offense(node) { |offense_node, message| add_offense(offense_node, message: message) }
  end

  alias on_defs on_def
  alias on_block on_def
  alias on_numblock on_def
  alias on_itblock on_def

  private
    def each_offense(node, &block)
      if block
        yield_accumulations(node.body, &block) if node.body&.begin_type?
      else
        to_enum(__method__, node)
      end
    end

    def yield_accumulations(body)
      statements = body.children
      statements.each_with_index do |assignment, index|
        name = empty_collection_assignment(assignment)
        yield assignment, MESSAGE if name && AccumulationCheck.new(statements[(index + 1)..], name).match?
      end
    end

    class AccumulationCheck
      extend RuboCop::AST::NodePattern::Macros

      # @!method each_block?(node)
      def_node_matcher :each_block?, <<~PATTERN
        (any_block (send _ :each) ...)
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

        # The block must do nothing but the mutation (optionally behind a one-armed
        # `if`/`unless` guard). Any extra statement means a declarative `map`/`select`
        # would drop a side effect, so the loop is left alone.
        def mutates_in_body?(body)
          mutates_variable?(body, variable_name) || guarded_mutation?(body)
        end

        def guarded_mutation?(body)
          body&.if_type? && body.else_branch.nil? && mutates_variable?(body.if_branch, variable_name)
        end

        def returns_variable?
          variable_reference(statements.last) == variable_name
        end
    end
end
