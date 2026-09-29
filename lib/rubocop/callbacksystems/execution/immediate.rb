# The nodes an expression can execute now, without entering a definition or a callable whose body runs later.
class RuboCop::Callbacksystems::Execution::Immediate
  include Enumerable

  def initialize(node, deferred_blocks: [])
    @node = node
    @deferred_blocks = {}.compare_by_identity
    deferred_blocks.each { @deferred_blocks[it] = true }
  end

  def nodes_of_type(*types)
    select { it.type?(*types) }
  end

  def each
    if block_given?
      execution.each { yield it }
    else
      enum_for
    end
  end

  private
    attr_reader :node, :deferred_blocks

    def execution
      Traversal.new(node, deferred_blocks)
    end

    # An iterative walk that keeps its cursor and pending nodes together with the shared boundary index.
    class Traversal
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, deferred_blocks)
        @pending = [ node ]
        @deferred_blocks = deferred_blocks
      end

      def each
        until pending.empty?
          advance
          visit { yield it } if current
        end
      end

      private
        attr_reader :pending, :deferred_blocks, :current

        def advance
          @current = pending.pop
        end

        def visit
          if execution_boundary?
            queue immediate_inputs_of(current)
          else
            yield current
            queue current.each_child_node
          end
        end

        def execution_boundary?
          lexical_definition?(current) || deferred_callable_block?(current) || method_definition_block?(current) ||
            deferred_blocks.key?(current)
        end

        def queue(nodes)
          pending.concat(nodes.to_a.reverse)
        end
    end
end
