module RuboCop::Callbacksystems::Helpers::NodeTypes
  BLOCK_NODE_TYPES = %i[block numblock itblock].freeze

  def any_block_type?(node)
    node && BLOCK_NODE_TYPES.include?(node.type)
  end

  def constant_name(node)
    return unless node

    case node.type
    when :const
      if node.namespace
        "#{constant_name(node.namespace)}::#{node.short_name}"
      else
        node.short_name.to_s
      end
    when :cbase
      ""
    end
  end
end
