class RuboCop::Callbacksystems::ClassStructure::NodeVisibility
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  def public?
    level == :public
  end

  def level
    level_of_wrapping_modifier || explicitly_assigned_level || default_level
  end

  def enclosing_body
    visibility_owner&.body&.then { it if it.type?(:begin, :kwbegin) }
  end

  def enclosing_definition
    node.each_ancestor(:class, :module, :sclass).first
  end

  def level_in(body)
    RuboCop::Callbacksystems::ClassStructure::Visibility.for(body).level_at(node)
  end

  def private?
    level == :private
  end

  def protected?
    level == :protected
  end

  def private_non_predicate?
    level != :public && !node.predicate_method?
  end

  private
    attr_reader :node

    def level_of_wrapping_modifier
      visibility_applied_to(node.parent, node)
    end

    def explicitly_assigned_level
      assignment_bodies.filter_map do |body|
        RuboCop::Callbacksystems::ClassStructure::Visibility.for(body).assignment_after \
          node, singleton: node.defs_type? || body.equal?(singleton_owner_body)
      end.max_by(&:position)&.level
    end

    def assignment_bodies
      [ enclosing_body, singleton_owner_body ].compact.uniq(&:object_id)
    end

    def singleton_owner_body
      singleton_class&.each_ancestor&.find { visibility_owner?(it) }&.body
    end

    def singleton_class
      @singleton_class ||= visibility_owner if visibility_owner&.sclass_type? &&
        visibility_owner.children.first.self_type?
    end

    def visibility_owner
      @visibility_owner ||= node.each_ancestor.find { visibility_owner?(it) }
    end

    def visibility_owner?(candidate)
      candidate.type?(:class, :module, :sclass) || any_block_type?(candidate)
    end

    def default_level
      if !node.defs_type? && enclosing_body
        level_in(enclosing_body)
      else
        :public
      end
    end
end
