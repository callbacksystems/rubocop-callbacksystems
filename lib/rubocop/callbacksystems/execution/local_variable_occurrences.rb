# Local-variable nodes indexed by lexical scope, so several readings of one scope walk its tree only once.
class RuboCop::Callbacksystems::Execution::LocalVariableOccurrences
  include RuboCop::Callbacksystems::Helpers

  def initialize(tree)
    @tree = tree
    @by_scope = {}.compare_by_identity
  end

  def named(name, around:)
    occurrences_around(around).fetch(name) { [] }
  end

  def named_in_method(name, around:)
    occurrences_in(enclosing_method_of(around)).fetch(name) { [] }
  end

  private
    attr_reader :tree, :by_scope

    def occurrences_around(node)
      occurrences_in(scope_of(node))
    end

    def occurrences_in(scope)
      if scope
        by_scope[scope] ||= OccurrencesWithin.new(scope).group_by { variable_name_of(it) }
      else
        {}
      end
    end

    def scope_of(node)
      enclosing_scope_of(node) || tree
    end

    class OccurrencesWithin
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(scope)
        @scope = scope
      end

      def each
        if block_given?
          each_occurrence { yield it }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :scope

        def each_occurrence
          pending = [ Candidate.new(scope, scope:, nested: false) ]
          until pending.empty?
            candidate = pending.pop
            yield candidate.node if candidate.occurrence?
            candidate.children.reverse_each { pending << it }
          end
        end

        class Candidate
          include RuboCop::Callbacksystems::Helpers

          attr_reader :node

          def initialize(node, scope:, nested:)
            @node = node
            @scope = scope
            @nested = nested
          end

          def occurrence?
            local_node? && !rebound?
          end

          def children
            child_nodes.map { self.class.new(it, scope:, nested: true) }
          end

          private
            attr_reader :scope, :nested

            def local_node?
              node.type?(:lvar, :lvasgn, :match_var)
            end

            def rebound?
              name_rebound_between?(variable_name_of(node), node:, boundary: scope)
            end

            def child_nodes
              if nested && execution_boundary?
                immediate_inputs_of(node)
              else
                node.each_child_node
              end
            end

            def execution_boundary?
              lexical_definition?(node) || deferred_boundary?
            end

            def deferred_boundary?
              deferred_callable_block?(node) || method_definition_block?(node)
            end
        end
    end
end
