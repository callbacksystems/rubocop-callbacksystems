class RuboCop::Callbacksystems::MacroReferencedMethods
  include RuboCop::Callbacksystems::Helpers

  class << self
    def for(body)
      body ? new(body).all : Set.new
    end
  end

  def initialize(body)
    @body = body
  end

  def all
    Set.new(collect_from(body))
  end

  private
    attr_reader :body

    # Macros live at the class/module body level, never inside a method body; skipping
    # methods keeps ordinary symbol arguments and block calls from looking like macros.
    def collect_from(node)
      if node.is_a?(RuboCop::AST::Node) && !node.type?(:def, :defs)
        Node.new(node).references + node.children.flat_map { collect_from(it) }
      else
        []
      end
    end

    # One node at the body level, resolved to the method names it references as a macro.
    class Node
      include RuboCop::Callbacksystems::Helpers

      CALLBACK_OPTIONS = %i[if unless].freeze

      def initialize(node)
        @node = node
      end

      def references
        case
        when node.send_type? then from_send
        when any_block_type?(node) then receiverless_method_names_in(node.body)
        else []
        end
      end

      private
        attr_reader :node

        def from_send
          first_symbol_argument + lambda_argument_calls + hash_option_references
        end

        def first_symbol_argument
          symbol = node.arguments.find(&:sym_type?)
          symbol ? [ symbol.value ] : []
        end

        def lambda_argument_calls
          node.arguments.select(&:block_type?).flat_map { receiverless_method_names_in(it.body) }
        end

        def hash_option_references
          node.arguments
            .select(&:hash_type?)
            .flat_map(&:pairs)
            .flat_map { option_reference(it.key, it.value) }
        end

        def option_reference(key, value)
          if key.sym_type?
            case key.value
            when :to then delegate_target_of(value)
            when *CALLBACK_OPTIONS then callback_condition_of(value)
            else []
            end
          else
            []
          end
        end

        def delegate_target_of(value)
          case value.type
          when :sym then [ value.value ]
          when :str then Array(value.value.split(".").first&.to_sym)
          else []
          end
        end

        def callback_condition_of(value)
          case value.type
          when :sym then [ value.value ]
          when :block then receiverless_method_names_in(value.body)
          else []
          end
        end
    end
end
