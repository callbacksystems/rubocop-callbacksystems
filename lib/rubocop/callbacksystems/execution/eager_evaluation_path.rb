# The path to a read where an already evaluated value can move without becoming conditional, running repeatedly, or
# crossing earlier work whose result the moved evaluation could change.
class RuboCop::Callbacksystems::Execution::EagerEvaluationPath
  SEQUENTIAL_PARENT_TYPES = %i[
    array begin block_pass break casgn csend cvasgn dstr dsym erange gvasgn hash irange ivasgn kwbegin lvasgn next pair
    kwsplat regexp return send splat super yield
  ]
  EAGER_FIRST_CHILD_PARENT_TYPES = %i[ and case case_match if or ]
  BLOCK_PARENT_TYPES = %i[ block numblock itblock ]
  INERT_NODE_TYPES = %i[ self lvar ]

  def initialize(read, within:)
    @read = read
    @boundary = within
  end

  def preserves_order?
    read_within_boundary? && steps_preserve_order?
  end

  private
    attr_reader :read, :boundary

    def read_within_boundary?
      read.equal?(boundary) || read.each_ancestor.any? { it.equal?(boundary) }
    end

    def steps_preserve_order?
      cursor = read
      cursor = cursor.parent while !cursor.equal?(boundary) && Step.new(cursor).preserves_order?
      cursor.equal?(boundary)
    end

    class Step
      def initialize(node)
        @node = node
      end

      def preserves_order?
        eager_once? && preceding_nodes.all? { inert?(it) }
      end

      private
        attr_reader :node

        delegate :parent, to: :node, private: true

        def eager_once?
          sequential? || eager_first_child? || immediate_block_call?
        end

        def sequential?
          SEQUENTIAL_PARENT_TYPES.include?(parent.type) &&
            (!parent.csend_type? || parent.receiver.equal?(node))
        end

        def eager_first_child?
          EAGER_FIRST_CHILD_PARENT_TYPES.include?(parent.type) && parent.children.first.equal?(node)
        end

        def immediate_block_call?
          BLOCK_PARENT_TYPES.include?(parent.type) && parent.send_node.equal?(node)
        end

        def preceding_nodes
          parent.each_child_node.take_while { !it.equal?(node) }
        end

        def inert?(candidate)
          candidate.recursive_basic_literal? || INERT_NODE_TYPES.include?(candidate.type)
        end
    end
end
