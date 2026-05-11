class RuboCop::Callbacksystems::FixtureCall
  def initialize(node)
    @node = node
  end

  attr_reader :node

  def valid?
    node&.send_type? &&
      !node.receiver &&
      node.arguments.size == 1 &&
      node.first_argument.sym_type? &&
      pluralized_method_name?
  end

  def signature
    "#{node.method_name}(:#{node.first_argument.value})"
  end

  private
    def pluralized_method_name?
      name = node.method_name.to_s
      name.singularize.pluralize == name
    end
end
