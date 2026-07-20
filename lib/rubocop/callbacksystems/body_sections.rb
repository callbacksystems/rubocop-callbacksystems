class RuboCop::Callbacksystems::BodySections
  include RuboCop::Callbacksystems::Helpers

  def initialize(body)
    @body = body
  end

  def public_method_nodes
    public_children.select(&:def_type?)
  end

  def each_child_with_visibility(&block)
    if block && body
      in_private = false
      body.each_child_node do |child|
        in_private = true if visibility_modifier_of(child) == :private
        yield child, in_private
      end
    else
      to_enum(__method__)
    end
  end

  def private_method_nodes
    private_children.select(&:def_type?)
  end

  def private_nested_classes
    private_children.select(&:class_type?)
  end

  def private_modifier
    statements_in(body).find { visibility_modifier_of(it) == :private }
  end

  private
    attr_reader :body

    def public_children
      each_child_with_visibility.filter_map { |child, in_private| child unless in_private }
    end

    def private_children
      each_child_with_visibility.filter_map { |child, in_private| child if in_private }
    end
end
