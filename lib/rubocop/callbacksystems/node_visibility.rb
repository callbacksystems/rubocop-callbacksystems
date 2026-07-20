class RuboCop::Callbacksystems::NodeVisibility
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  def public?
    level == :public
  end

  def level
    enclosing_body ? level_in(enclosing_body) : :public
  end

  def enclosing_body
    enclosing_definition&.body&.then { it if it.type?(:begin, :kwbegin) }
  end

  def enclosing_definition
    node.each_ancestor(:class, :module, :sclass).first
  end

  def level_in(body)
    current = :public
    body.each_child_node do |child|
      break current if child.equal?(node)

      current = visibility_modifier_of(child) || current
    end
  end

  def private?
    level == :private
  end

  def private_non_predicate?
    level != :public && !node.predicate_method?
  end

  private
    attr_reader :node
end
