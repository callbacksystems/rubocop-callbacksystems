module RuboCop::Callbacksystems::Helpers::Methods
  PARAMETER_TYPES = %i[ arg optarg kwarg kwoptarg ]

  BUILDER_METHODS = %i[
    new
    create build update
    assign_attributes update_attribute update_column update_columns
    find find_by find_sole_by
    find_or_create_by find_or_initialize_by create_or_find_by
    destroy_by delete_by
    permit expect
  ].to_set

  def builder_method?(node)
    BUILDER_METHODS.include?(node.method_name)
  end

  def parameter_names_of(method_node)
    parameter_nodes_of(method_node).map { it.children.first.to_s }
  end

  def parameter_nodes_of(method_node)
    method_node.arguments.children.select { parameter_node?(it) }
  end

  def parameter_node?(node)
    node&.type?(*PARAMETER_TYPES)
  end

  def inside_initialize?(node)
    node.each_ancestor(:any_def).any? { it.method?(:initialize) }
  end

  # A definition below another method or a block may belong to a receiver established only at runtime. Attribute only
  # definitions whose path to the nearest named class or module crosses neither boundary.
  def direct_method_definition?(node)
    enclosing_class_or_module_of(node)&.then do |owner|
      node.each_ancestor.take_while { !it.equal?(owner) }
        .none? { it.any_def_type? || any_block_type?(it) }
    end || false
  end

  def single_send_private_non_predicate?(method_node)
    method_node.body&.send_type? && private_method?(method_node) && !method_node.predicate_method?
  end
end
