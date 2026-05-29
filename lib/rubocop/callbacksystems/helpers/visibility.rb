module RuboCop::Callbacksystems::Helpers::Visibility
  def public_method?(method_node)
    visibility_of(method_node) == :public
  end

  def visibility_of(method_node)
    body = enclosing_body_for(method_node)
    body ? visibility_at(method_node, body) : :public
  end

  def enclosing_body_for(method_node)
    method_node.each_ancestor(:class, :module, :sclass).first&.body&.then { it if it.type?(:begin, :kwbegin) }
  end

  def visibility_at(method_node, body)
    current = :public
    body.each_child_node do |child|
      break current if child.equal?(method_node)

      current = visibility_modifier_of(child) || current
    end
  end

  def visibility_modifier_of(node)
    if bare_send?(node) && node.arguments.empty?
      node.method_name if %i[private protected public].include?(node.method_name)
    end
  end

  def private_method?(method_node)
    visibility_of(method_node) == :private
  end

  def private_non_predicate?(method_node)
    visibility_of(method_node) != :public && !method_node.predicate_method?
  end

  def private_nested_class?(class_node)
    enclosing = enclosing_class_or_module_of(class_node)
    enclosing && private_nested_classes_in(enclosing).include?(class_node)
  end

  def enclosing_class_or_module_of(node)
    node.each_ancestor(:class, :module).first
  end

  def private_nested_classes_in(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if in_private && child.class_type? }
  end

  def each_child_with_visibility(class_node, &block)
    if block && class_node.body
      in_private = false
      class_node.body.each_child_node do |child|
        in_private = true if visibility_modifier_of(child) == :private
        yield child, in_private
      end
    else
      to_enum(__method__, class_node)
    end
  end

  def public_methods_in(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if !in_private && child.def_type? }
  end

  def private_methods_in(class_node)
    each_child_with_visibility(class_node).filter_map { |child, in_private| child if in_private && child.def_type? }
  end
end
