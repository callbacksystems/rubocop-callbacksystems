module RuboCop::Callbacksystems::Helpers::Methods
  PARAMETER_TYPES = %i[arg optarg kwarg kwoptarg].freeze

  def parameter_names_of(method_node)
    method_node.arguments.children.select { parameter_node?(it) }.map { it.children.first.to_s }
  end

  def parameter_node?(node)
    node&.type?(*PARAMETER_TYPES)
  end

  def inside_initialize?(node)
    node.each_ancestor(:any_def).any? { it.method?(:initialize) }
  end

  def single_send_private_non_predicate?(method_node)
    method_node.body&.send_type? && private_non_predicate?(method_node)
  end
end
