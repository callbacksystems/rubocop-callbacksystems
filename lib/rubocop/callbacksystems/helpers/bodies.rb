module RuboCop::Callbacksystems::Helpers::Bodies
  def assignment_count(body, *types)
    ScopedAssignments.new(body, types).to_set { variable_name_of(it) }.size
  end

  def immediate_inputs_of(node)
    if any_block_type?(node)
      call_of(node).then { [ it.receiver, *it.arguments ].compact }
    else
      case node.type
      when :defs then [ node.receiver ]
      when :class then [ node.identifier, node.parent_class ].compact
      when :sclass then [ node.identifier ]
      else []
      end
    end
  end

  def lexical_definition?(node)
    node.type?(:def, :defs, :class, :module, :sclass)
  end

  def statements_before(node)
    node.parent&.type?(:begin, :kwbegin) ? node.parent.children.take_while { !it.equal?(node) } : []
  end

  def direct_definitions_in(body, type)
    statements_in(body).select { it.type?(type) }
  end

  def statements_in(body)
    if body
      body.type?(:begin, :kwbegin) ? body.children.to_a : [ body ]
    else
      []
    end
  end

  def runs_in(body)
    statements_in(body).chunk_while { |left, right| yield(left) && yield(right) }.select { yield it.first }
  end

  def receiverless_method_names_in(body)
    nodes_in(body, :send).filter_map { it.method_name if bare_send?(it) }
  end

  def first_statement_in(body)
    edge_statement(body, side: :first)
  end

  def last_statement_in(body)
    edge_statement(body, side: :last)
  end

  def direct_method_nodes_in(body)
    DirectMethodNodes.new(body).to_a
  end

  private
    def edge_statement(body, side:)
      current = body
      loop do
        current = case current&.type
        when :begin, :kwbegin then current.children.public_send(side)
        when :rescue then current.body
        when :ensure then current.children.first
        else return current
        end
      end
    end

    # Method definitions belonging directly to a body, with singleton sections transparent and other owners pruned.
    class DirectMethodNodes
      include Enumerable

      def initialize(body)
        @body = body
      end

      def each
        if block_given?
          pending = [ body ].compact
          until pending.empty?
            node = pending.pop
            case node.type
            when :def, :defs then yield node
            when :begin, :kwbegin then pending.concat(node.each_child_node.to_a.reverse)
            when :sclass then pending << node.body if node.body
            end
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :body
    end

    # Assignments executed in one lexical scope, with callable and definition bodies left for their own scopes.
    class ScopedAssignments
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, types)
        @body = body
        @types = types
      end

      def each
        if block_given?
          @pending = [ body ].compact
          until pending.empty?
            advance
            visit { yield it }
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :body, :types, :pending, :current

        def advance
          @current = pending.pop
        end

        def visit
          if scope_boundary?
            queue immediate_inputs_of(current)
          else
            yield current if current.type?(*types)
            queue current.each_child_node
          end
        end

        def scope_boundary?
          (!current.equal?(body) && lexical_definition?(current)) || deferred_boundary?
        end

        def deferred_boundary?
          deferred_callable_block?(current) || method_definition_block?(current)
        end

        def queue(nodes)
          pending.concat(nodes.to_a.reverse)
        end
    end
end
