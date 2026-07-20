module RuboCop::Callbacksystems::Helpers::Visibility
  def public_method?(node)
    visibility_for(node).public?
  end

  def visibility_of(node)
    visibility_for(node).level
  end

  def visibility_at(node, body)
    visibility_for(node).level_in(body)
  end

  def enclosing_body_for(node)
    visibility_for(node).enclosing_body
  end

  def enclosing_definition_of(node)
    visibility_for(node).enclosing_definition
  end

  def private_modifier_in(body)
    statements_in(body).find { visibility_modifier_of(it) == :private }
  end

  def visibility_modifier_of(node)
    if bare_send?(node) && node.arguments.empty?
      node.method_name if %i[private protected public].include?(node.method_name)
    end
  end

  def private_method?(node)
    visibility_for(node).private?
  end

  def private_non_predicate?(node)
    visibility_for(node).private_non_predicate?
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

  private
    def visibility_for(node)
      RuboCop::Callbacksystems::NodeVisibility.new(node)
    end
end
