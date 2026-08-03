module RuboCop::Callbacksystems::Helpers::NodeTypes
  BLOCK_NODE_TYPES = %i[block numblock itblock].freeze
  DECLARATION_MACROS = %i[attr_reader attr_accessor attr_writer delegate].freeze
  CLASS_BUILDERS = { Data: :define, Struct: :new, Class: :new }.freeze

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

  # A class definition carrying behavior, written as a class or built from
  # `Data.define`, `Struct.new` or `Class.new` with a block.
  def class_with_body?(node)
    node.class_type? ? node.body.present? : class_builder_with_block?(node)
  end

  def any_block_type?(node)
    node && BLOCK_NODE_TYPES.include?(node.type)
  end

  def class_name_of(node)
    node.class_type? ? node.identifier.source : node.name.to_s
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

  private
    def class_builder_with_block?(node)
      node.casgn_type? && any_block_type?(node.expression) && class_builder?(node.expression.send_node)
    end

    def class_builder?(call)
      CLASS_BUILDERS[builder_name_of(call)] == call.method_name
    end

    def builder_name_of(call)
      call.receiver.short_name if call.receiver&.const_type?
    end

    def heredoc_literal?(node)
      node.type?(:str, :dstr, :xstr) && node.heredoc?
    end
end
