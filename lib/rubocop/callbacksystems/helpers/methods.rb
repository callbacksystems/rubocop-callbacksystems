module RuboCop::Callbacksystems::Helpers::Methods
  def parameter_names(method_node)
    method_node.arguments.children
      .select { it.type?(:arg, :optarg, :kwarg, :kwoptarg) }
      .map { it.children.first.to_s }
  end
end
