module RuboCop::Callbacksystems::Helpers::Visibility
  LEVELS = %i[ public protected private ]

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

  def visibility_applied_to(node, definition)
    if bare_send?(node) && node.arguments.include?(definition)
      wrapped_visibility(node.method_name, definition)
    end
  end

  def private_method?(node)
    visibility_for(node).private?
  end

  def protected_method?(node)
    visibility_for(node).protected?
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

  def public_methods_in(class_node)
    sections_in(class_node.body).public_method_nodes
  end

  def private_methods_in(class_node)
    sections_in(class_node.body).private_method_nodes
  end

  def enclosing_method_of(node)
    node.each_ancestor(:any_def).first
  end

  def enclosing_scope_of(node)
    node.each_ancestor(:any_def, :any_block).first
  end

  def sibling_method_nodes_of(node)
    direct_method_nodes_in(enclosing_class_or_module_of(node)&.body)
  end

  def leaves_public_section?(node)
    %i[ private protected ].include?(visibility_modifier_of(node))
  end

  def visibility_modifier_of(node)
    if bare_send?(node) && node.arguments.empty?
      node.method_name if LEVELS.include?(node.method_name)
    end
  end

  def private_constant_names_of(node)
    names_marked_by(node, macro: :private_constant).map { it.value.to_sym }
  end

  def names_marked_by(node, macro:)
    bare_send?(node) && node.method?(macro) ? name_arguments_of(node) : []
  end

  private
    def visibility_for(node)
      RuboCop::Callbacksystems::ClassStructure::NodeVisibility.new(node)
    end

    def sections_in(body)
      RuboCop::Callbacksystems::ClassStructure::ClassBody.new(body)
    end

    def wrapped_visibility(modifier, definition)
      case modifier
      when *LEVELS then modifier if definition.def_type?
      when :private_class_method then :private if self_singleton_definition?(definition)
      when :public_class_method then :public if self_singleton_definition?(definition)
      end
    end

    def self_singleton_definition?(definition)
      definition.defs_type? && definition.receiver.self_type?
    end
end
