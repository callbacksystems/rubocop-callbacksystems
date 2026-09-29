# A constant assignment whose expression uses one of Ruby's root class or module builders.
class RuboCop::Callbacksystems::ClassStructure::BuilderAssignment
  include RuboCop::Callbacksystems::Helpers

  CLASS_BUILDERS = { Data: :define, Struct: :new, Class: :new }
  MODULE_BUILDERS = { Module: :new }

  def initialize(node)
    @node = node
  end

  def builds_class_with_body?
    builds_class? && block_with_body?
  end

  def builds_class?
    builds?(CLASS_BUILDERS)
  end

  def builds_module_with_body?
    builds_module? && block_with_body?
  end

  def builds_module?
    builds?(MODULE_BUILDERS)
  end

  private
    attr_reader :node

    def builds?(builders)
      builder_named_in?(builders)
    end

    def builder_named_in?(builders)
      builder_call&.receiver.then do |receiver|
        core_constant?(receiver) && builders[receiver.short_name] == builder_call.method_name
      end
    end

    def builder_call
      @builder_call ||= call_of(node.expression) if node&.casgn_type?
    end

    def block_with_body?
      any_block_type?(node.expression) && node.expression.body.present?
    end
end
