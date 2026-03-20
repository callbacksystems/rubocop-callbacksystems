# Collects public method names from an AST node (class or module body).
# Traverses through blocks (class_methods, included, etc.), class << self,
# and respects visibility modifiers (private/protected).
#
# @example
#   MethodCollector.new(class_node_ast).collect  # => [:name, :email, :admin?]
#
class RuboCop::Callbacksystems::MethodCollector
  attr_reader :ast, :methods

  def initialize(ast)
    @ast = ast
    @methods = []
  end

  def collect
    traverse(ast, top_level: true, public_section: true)
    methods
  end

  private
    def traverse(node, top_level:, public_section:)
      return unless node

      add_method_name(node, public_section) || traverse_children(node, top_level: top_level, public_section: public_section)
    end

    def add_method_name(node, public_section)
      return unless public_method?(node, public_section)

      methods << method_name_for(node)
    end

    def public_method?(node, public_section)
      public_section && (method_definition?(node) || scope_definition?(node))
    end

    def method_name_for(node)
      scope_definition?(node) ? node.first_argument.value : node.method_name
    end

    def method_definition?(node)
      %i[def defs].include?(node.type)
    end

    def scope_definition?(node)
      node.type == :send && node.method_name == :scope && node.first_argument&.sym_type?
    end

    def traverse_children(node, top_level:, public_section:)
      case node.type
      when :class, :module
        traverse(node.body, top_level: false, public_section: true) if top_level
      when :begin
        traverse_begin(node, top_level: top_level, public_section: public_section)
      when :sclass, :block
        traverse(node.body, top_level: false, public_section: true)
      end
    end

    def traverse_begin(node, top_level:, public_section:)
      current_public = public_section
      node.children.each do |child|
        current_public = false if visibility_modifier?(child)
        child_is_class_or_module = %i[class module].include?(child.type)
        traverse(child, top_level: top_level && child_is_class_or_module, public_section: current_public)
      end
    end

    def visibility_modifier?(node)
      node.type == :send && node.receiver.nil? && %i[private protected].include?(node.method_name) && node.arguments.empty?
    end
end
