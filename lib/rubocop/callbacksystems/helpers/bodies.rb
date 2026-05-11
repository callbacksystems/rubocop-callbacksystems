module RuboCop::Callbacksystems::Helpers::Bodies
  def first_statement(body)
    case body&.type
    when :begin, :kwbegin then body.children.first
    when :rescue then first_statement(body.body)
    when :ensure then first_statement(body.children.first)
    else body
    end
  end

  def last_statement(body)
    case body&.type
    when :begin, :kwbegin then body.children.last
    when :rescue then last_statement(body.body)
    when :ensure then last_statement(body.children.first)
    else body
    end
  end

  def assignment_count(body, type)
    body&.each_node(type)&.to_set { it.children.first }&.size || 0
  end

  def direct_method_nodes(body)
    return [] unless body

    case body.type
    when :def, :defs then [ body ]
    when :begin, :kwbegin then body.each_child_node.flat_map { direct_method_nodes(it) }
    when :sclass then direct_method_nodes(body.body)
    else []
    end
  end
end
