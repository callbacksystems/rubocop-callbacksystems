module RuboCop::Callbacksystems::Helpers::Bodies
  def assignment_count(body, type)
    body&.each_node(type)&.to_set { it.children.first }&.size || 0
  end

  def statements_in(body)
    if body
      body.type?(:begin, :kwbegin) ? body.children.to_a : [ body ]
    else
      []
    end
  end

  def receiverless_method_names_in(body)
    body ? body.each_node(:send).filter_map { it.method_name if bare_send?(it) } : []
  end

  def first_statement_in(body)
    edge_statement(body, side: :first)
  end

  def last_statement_in(body)
    edge_statement(body, side: :last)
  end

  def direct_method_nodes_in(body)
    if body
      case body.type
      when :def, :defs then [ body ]
      when :begin, :kwbegin then body.each_child_node.flat_map { direct_method_nodes_in(it) }
      when :sclass then direct_method_nodes_in(body.body)
      else []
      end
    else
      []
    end
  end

  private
    def edge_statement(body, side:)
      case body&.type
      when :begin, :kwbegin then body.children.public_send(side)
      when :rescue then edge_statement(body.body, side:)
      when :ensure then edge_statement(body.children.first, side:)
      else body
      end
    end
end
