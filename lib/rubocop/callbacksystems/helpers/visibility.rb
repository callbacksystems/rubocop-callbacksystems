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
    sections_in(body).private_modifier
  end

  def in_private_section?(node, body)
    sections_in(body).in_private_section?(node)
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
    sections_in(class_node.body).private_nested_classes
  end

  def each_child_with_visibility(class_node, &block)
    sections_in(class_node.body).each_child_with_visibility(&block)
  end

  def public_methods_in(class_node)
    sections_in(class_node.body).public_method_nodes
  end

  def private_methods_in(class_node)
    sections_in(class_node.body).private_method_nodes
  end

  private
    def visibility_for(node)
      RuboCop::Callbacksystems::NodeVisibility.new(node)
    end

    def sections_in(body)
      RuboCop::Callbacksystems::BodySections.new(body)
    end
end
