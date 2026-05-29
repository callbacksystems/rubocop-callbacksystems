module RuboCop::Callbacksystems::Helpers::NodeTypes
  BLOCK_NODE_TYPES = %i[block numblock itblock].freeze

  def any_block_type?(node)
    node && BLOCK_NODE_TYPES.include?(node.type)
  end

  def bare_send?(node)
    node&.send_type? && node.receiver.nil?
  end

  def reads_variable?(node, variable_name)
    node&.type?(:lvar, :ivar) && node.name == variable_name
  end

  def constant_name_of(node)
    if node
      case node.type
      when :const
        if node.namespace
          "#{constant_name_of(node.namespace)}::#{node.short_name}"
        else
          node.short_name.to_s
        end
      when :cbase
        ""
      end
    end
  end
end
