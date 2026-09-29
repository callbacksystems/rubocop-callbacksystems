module RuboCop::Callbacksystems::Helpers::Variables
  def deferred_callable_block?(node)
    if any_block_type?(node)
      call = call_of(node)

      kernel_callable?(call) || proc_constructor?(call)
    else
      false
    end
  end

  def method_definition_block?(node)
    any_block_type?(node) && METHOD_DEFINITION_CALLS.include?(call_of(node).method_name)
  end

  def variable_name_of(node)
    node.match_var_type? ? node.children.first : node.name
  end

  def conditional_return_of_block_argument?(return_node, block:)
    value = return_node.children.first

    return_node.parent.if_type? && value&.lvar_type? && block.argument_list.any? { it.name == value.name } &&
      !name_rebound_between?(value.name, node: return_node, boundary: block)
  end

  def name_rebound_between?(name, node:, boundary:)
    node.each_ancestor(:any_block).take_while { !it.equal?(boundary) }.any? do |block|
      block.argument_list.any? { it.respond_to?(:name) && it.name.to_s == name.to_s }
    end
  end

  private
    METHOD_DEFINITION_CALLS = %i[ define_method define_singleton_method ]

    def kernel_callable?(call)
      %i[ lambda proc ].include?(call.method_name) &&
        (call.receiver.nil? || (core_constant?(call.receiver) && call.receiver.short_name == :Kernel))
    end

    def proc_constructor?(call)
      call.method?(:new) && core_constant?(call.receiver) && call.receiver.short_name == :Proc
    end
end
