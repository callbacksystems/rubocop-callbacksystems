# Source nodes that can name or expose a method, indexed in one walk and shared by every cop reading the same AST.
class RuboCop::Callbacksystems::Methods::ReferenceEvidence
  IDENTIFIER_PATTERN = /[a-zA-Z_]\w*[?!=]?/

  delegate :calls, :block_passes, :alias_nodes, :literals, :interpolated_literals, to: :nodes

  class << self
    def for(root)
      mutex.synchronize { cache[root] ||= new(root) }
    end

    private
      def mutex
        @mutex ||= Mutex.new
      end

      def cache
        @cache ||= ObjectSpace::WeakMap.new
      end
  end

  def initialize(root)
    @root = root
  end

  def macro_referenced_methods
    @macro_referenced_methods ||= RuboCop::Callbacksystems::Methods::MacroReferences.new(root).to_set
  end

  def literal_method_names
    @literal_method_names ||= literals.flat_map do |literal|
      if literal.sym_type?
        literal.value.to_s
      else
        literal.value.to_s.scrub.scan(IDENTIFIER_PATTERN)
      end
    end.to_set
  end

  private
    attr_reader :root

    def nodes
      @nodes ||= Nodes.new(root)
    end

    # The relevant node kinds partitioned during one traversal without losing source order between send and csend.
    class Nodes
      TYPES = %i[ alias block_pass csend dstr dsym send str sym ]

      attr_reader :calls, :block_passes, :alias_nodes, :literals, :interpolated_literals

      def initialize(root)
        @calls = []
        @block_passes = []
        @alias_nodes = []
        @literals = []
        @interpolated_literals = []

        root.each_node(*TYPES).each { partition(it) }
      end

      private
        def partition(node)
          case node.type
          when :send, :csend then calls << node
          when :block_pass then block_passes << node
          when :alias then alias_nodes << node
          when :str, :sym then literals << node
          when :dstr, :dsym then interpolated_literals << node
          end
        end
    end
end
