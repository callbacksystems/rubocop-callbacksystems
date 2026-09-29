class RuboCop::Callbacksystems::ClassStructure::ClassBody
  include RuboCop::Callbacksystems::Helpers

  def initialize(body)
    @body = body
  end

  def public_method_nodes
    public_children.select(&:def_type?)
  end

  def public_children
    each_child_with_visibility.filter_map { |child, level| child if level == :public }
  end

  def each_child_with_visibility
    if block_given?
      visibility.each_statement { |child, level| yield child, level }
    else
      visibility.each_statement
    end
  end

  def private_method_nodes
    private_children.select(&:def_type?)
  end

  def private_nested_classes
    private_children.select(&:class_type?)
  end

  def in_private_section?(node)
    visibility.level_at(node) == :private
  end

  def private_modifier
    statements_in(body).find { visibility_modifier_of(it) == :private }
  end

  private
    attr_reader :body

    def visibility
      @visibility ||= RuboCop::Callbacksystems::ClassStructure::Visibility.for(body)
    end

    def private_children
      each_child_with_visibility.filter_map { |child, level| child if level == :private }
    end
end
