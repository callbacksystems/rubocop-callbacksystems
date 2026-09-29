# The class or module and instance/singleton side where a method definition or receiverless call resolves.
class RuboCop::Callbacksystems::Methods::Domain
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  def container
    @container ||= domain_node.each_ancestor.find { method_owner_boundary?(it) }
  end

  def scope
    singleton? ? :singleton : :instance
  end

  def singleton?
    singleton_depth.positive?
  end

  def singleton_depth
    identity.size
  end

  def identity
    @identity ||= singleton_path.freeze
  end

  private
    attr_reader :node

    def domain_node
      method_node || node
    end

    def method_node
      node.any_def_type? ? node : enclosing_method_of(node)
    end

    # A block around a definition may establish its receiver only when it runs (`Class.new`, `included`, `class_eval`,
    # and user macros). Treat it as an opaque owner rather than attributing the definition to the named outer class.
    def method_owner_boundary?(candidate)
      candidate.type?(:class, :module) || any_block_type?(candidate)
    end

    def singleton_path
      lexical_singleton_classes.reverse_each.map { singleton_class_identity(it) }.tap do |path|
        path << explicit_singleton_identity if explicit_singleton?
      end
    end

    def lexical_singleton_classes
      domain_node.each_ancestor(:sclass, :class, :module).take_while { !it.type?(:class, :module) }.to_a
    end

    def singleton_class_identity(singleton_class)
      singleton_class.children.first.self_type? ? :self : [ :expression, singleton_class.source_range.begin_pos ]
    end

    def explicit_singleton?
      if method_node
        method_node.defs_type?
      else
        !container.nil?
      end
    end

    # A definition on some other object does not belong to the container's class side. Its own body still shares this
    # identity with the receiverless calls it holds, while definitions on unrelated expressions remain separate.
    def explicit_singleton_identity
      if method_node&.defs_type? && !method_node.receiver.self_type?
        [ :expression, method_node.receiver.source_range.begin_pos ]
      else
        :self
      end
    end
end
