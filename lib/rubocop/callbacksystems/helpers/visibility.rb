module RuboCop::Callbacksystems::Helpers::Visibility
  def method_visibility(method_node)
    body = enclosing_body_for(method_node)
    body ? visibility_at(method_node, body) : :public
  end

  def visibility_modifier(node)
    return unless node.send_type? && node.arguments.empty?

    node.method_name if %i[private protected public].include?(node.method_name)
  end

  def enclosing_body_for(method_node)
    method_node.each_ancestor(:class, :module, :sclass).first&.body&.then { it if it.type?(:begin, :kwbegin) }
  end

  def visibility_at(method_node, body)
    current = :public
    body.each_child_node do |child|
      break current if child.equal?(method_node)

      current = visibility_modifier(child) || current
    end
  end

  def each_child_with_visibility(class_node, &block)
    return to_enum(__method__, class_node) unless block && class_node.body

    in_private = false
    class_node.body.each_child_node do |child|
      in_private = true if visibility_modifier(child) == :private
      yield child, in_private
    end
  end

  def private_nested_classes(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if in_private && child.class_type? }
  end

  def public_methods_in(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if !in_private && child.def_type? }
  end

  def private_methods_in(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if in_private && child.def_type? }
  end

  def direct_child_of_class?(method_node, class_node)
    method_node.each_ancestor(:class, :module).first == class_node
  end

  def private_non_predicate?(method_node)
    method_visibility(method_node) != :public && !method_node.predicate_method?
  end
end
