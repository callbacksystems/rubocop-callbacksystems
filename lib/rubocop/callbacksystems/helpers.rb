# Shared helper methods for Callbacksystems cops.
# Can be included in a cop class or called directly on the module.
#
module RuboCop::Callbacksystems::Helpers
  extend self

  # Returns the first statement from a method body.
  # Handles both single statements and begin/kwbegin blocks.
  #
  # @example
  #   first_statement(def_node.body)  # => first statement node
  #
  def first_statement(body)
    body.begin_type? || body.kwbegin_type? ? body.children.first : body
  end

  # Returns the last statement from a method body.
  # Handles both single statements and begin/kwbegin blocks.
  #
  # @example
  #   last_statement(def_node.body)  # => last statement node
  #
  def last_statement(body)
    body.begin_type? || body.kwbegin_type? ? body.children.last : body
  end

  # Counts unique variable assignments of the given type in a body.
  # Used for counting instance variables (:ivasgn) or local variables (:lvasgn).
  #
  # @example
  #   assignment_count(node.body, :ivasgn)  # => 3
  #   assignment_count(node.body, :lvasgn)  # => 5
  #
  def assignment_count(body, type)
    body.each_node(type).to_set { |node| node.children.first }.size
  end

  # Returns the full name of a constant node, handling namespaces.
  #
  # @example
  #   constant_name(node)  # => "Foo::Bar::Baz"
  #
  def constant_name(node)
    return unless node

    case node.type
    when :const
      if node.namespace
        "#{constant_name(node.namespace)}::#{node.short_name}"
      else
        node.short_name.to_s
      end
    when :cbase
      ""
    end
  end

  # Returns the visibility of a method node (:public, :private, or :protected).
  # Checks if the method is after a visibility modifier in the class body.
  #
  # @example
  #   method_visibility(def_node)  # => :private
  #
  def method_visibility(method_node)
    body = enclosing_body_for(method_node)
    body ? visibility_at(method_node, body) : :public
  end

  # Checks if a node is a visibility modifier (private, protected, public).
  #
  def visibility_modifier(node)
    return unless node.send_type? && node.arguments.empty?

    node.method_name if %i[private protected public].include?(node.method_name)
  end

  def enclosing_body_for(method_node)
    method_node.each_ancestor(:class, :module, :sclass).first&.body&.then { |b| b if b.begin_type? || b.kwbegin_type? }
  end

  def visibility_at(method_node, body)
    current = :public
    body.each_child_node do |child|
      current = visibility_modifier(child) || current
      break current if child.equal?(method_node)
    end
  end
end
