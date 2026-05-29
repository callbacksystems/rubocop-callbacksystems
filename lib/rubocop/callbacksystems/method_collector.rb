class RuboCop::Callbacksystems::MethodCollector
  include RuboCop::Callbacksystems::Helpers

  def initialize(ast)
    @ast = ast
  end

  def all
    top_level_definitions_in(ast).flat_map { Body.new(it.body).entries }
  end

  private
    attr_reader :ast

    def top_level_definitions_in(node)
      case node&.type
      when :class, :module then [ node ]
      when :begin then node.children.flat_map { top_level_definitions_in(it) }
      else []
      end
    end

    # The body of a class, module, or scope-defining construct.
    class Body
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def entries
        node&.begin_type? ? public_children.flat_map { Member.new(it).entries } : Member.new(node).entries
      end

      private
        attr_reader :node

        def public_children
          node.children.take_while { !leaves_public_section?(it) }
        end

        def leaves_public_section?(child)
          %i[private protected].include?(visibility_modifier_of(child))
        end
    end

    # One node within a body, resolved to the method or scope entries it defines.
    class Member
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def entries
        case node&.type
        when :def, :defs then [ [ node, node.method_name ] ]
        when :sclass, :block then Body.new(node.body).entries
        when :send then scope_entry
        else []
        end
      end

      private
        attr_reader :node

        def scope_entry
          scope_definition? ? [ [ node, node.first_argument.value ] ] : []
        end

        def scope_definition?
          bare_send?(node) && node.method?(:scope) && node.first_argument&.sym_type?
        end
    end
end
