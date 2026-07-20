module RuboCop::Callbacksystems::Helpers::NodeTypes
  BLOCK_NODE_TYPES = %i[block numblock itblock].freeze
  DECLARATION_MACROS = %i[attr_reader attr_accessor attr_writer delegate].freeze

  def any_block_type?(node)
    node && BLOCK_NODE_TYPES.include?(node.type)
  end

  def declaration_macro?(node)
    bare_send?(node) && DECLARATION_MACROS.include?(node.method_name)
  end

  def bare_send?(node)
    node&.send_type? && node.receiver.nil?
  end

  def singleton_section?(node)
    node&.sclass_type? && node.identifier.self_type?
  end

  # The constant a class or module definition names, as opposed to one its body
  # or superclass reads.
  def definition_identifier?(node)
    node.parent&.type?(:class, :module) && node.parent.identifier.equal?(node)
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
