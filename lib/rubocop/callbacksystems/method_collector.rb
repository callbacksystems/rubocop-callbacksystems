class RuboCop::Callbacksystems::MethodCollector
  include RuboCop::Callbacksystems::Helpers

  def initialize(ast)
    @ast = ast
    @results = []
  end

  def collect
    @top_level = true
    @public_section = true
    traverse(ast)
    results
  end

  private
    attr_reader :ast, :results

    def traverse(node)
      return unless node

      add_method(node) || traverse_children(node)
    end

    def add_method(node)
      return unless @public_section

      if node.type?(:def, :defs)
        results << [ node, node.method_name ]
      elsif scope_definition?(node)
        results << [ node, node.first_argument.value ]
      end
    end

    def scope_definition?(node)
      node.send_type? && node.method?(:scope) && node.first_argument&.sym_type?
    end

    def traverse_children(node)
      case node.type
      when :class, :module
        in_scope { traverse(node.body) } if @top_level
      when :begin
        traverse_begin(node)
      when :sclass, :block
        in_scope { traverse(node.body) }
      end
    end

    def traverse_begin(node)
      node.children.each do |child|
        @public_section = false if leaves_public_section?(child)
        saved_top_level = @top_level
        @top_level &&= child.type?(:class, :module)
        traverse(child)
        @top_level = saved_top_level
      end
    end

    def in_scope
      saved_top_level, saved_public_section = @top_level, @public_section
      @top_level = false
      @public_section = true
      yield
    ensure
      @top_level, @public_section = saved_top_level, saved_public_section
    end

    def leaves_public_section?(node)
      %i[private protected].include?(visibility_modifier(node))
    end
end
