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
    Set.new(ordered)
  end

  # References in source order, so a caller ordering these methods can lead with
  # them in the order the macros mention them.
  def ordered
    collect(body).uniq
  end

  private
    attr_reader :body

    # Macros live at the class/module body level, never inside a method body;
    # skipping bodies keeps ordinary symbol arguments and calls from looking like
    # macro uses.
    def collect(node)
      if node.is_a?(RuboCop::AST::Node) && !node.type?(:def, :defs)
        Node.new(node).references + node.children.flat_map { collect(it) }
      else
        []
      end
    end

    # One node at the body level, resolved to the method names it references as a macro.
    class Node
      include RuboCop::Callbacksystems::Helpers

      # Options whose symbol names a method the macro calls: the conditions that
      # guard a callback, and the handler `rescue_from` hands control to.
      METHOD_OPTIONS = %i[if unless with].freeze

      # Macros that define a method named after their symbol argument instead of
      # referencing an existing one. Their symbol is the method's name, not a call
      # to a `def` elsewhere (and `attr_writer :x` names `x=`, not `x`), so it must
      # not count as a reference. `delegate` is here for its leading names; its
      # `to:` target still counts through the hash options.
      DEFINING_MACROS = %i[
        attr_reader attr_writer attr_accessor
        mattr_reader mattr_writer mattr_accessor
        cattr_reader cattr_writer cattr_accessor
        thread_mattr_accessor thread_cattr_accessor
        class_attribute store_accessor attribute delegate
        scope enum composed_of define_method
        has_many has_one belongs_to has_and_belongs_to_many
        has_rich_text has_one_attached has_many_attached
      ].freeze

      # The one macro whose reference is not its leading symbol: `alias_method`
      # defines the first name and calls the second.
      ALIASING_MACRO = :alias_method

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

        # A callback condition (`if:`/`unless:`) is evaluated before the action it
        # guards, so it comes first, keeping guard-then-action in the order.
        def from_send
          hash_option_references + symbol_argument_reference + lambda_argument_calls
        end

        def hash_option_references
          hash_pairs.flat_map { option_reference(it.key, it.value) }
        end

        def hash_pairs
          node.arguments.select(&:hash_type?).flat_map(&:pairs)
        end

        def option_reference(key, value)
          if key.sym_type?
            case key.value
            when :to then delegate_target_of(value)
            when *METHOD_OPTIONS then method_option_of(value)
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

        def method_option_of(value)
          case value.type
          when :sym then [ value.value ]
          when :block then receiverless_method_names_in(value.body)
          else []
          end
        end

        # The symbol argument naming a method the macro will call. Most macros
        # lead with it, the defining ones name a method they create rather than
        # one to call, and `alias_method` calls the second of its two.
        def symbol_argument_reference
          case node.method_name
          when ALIASING_MACRO then symbol_values.drop(1).take(1)
          when *DEFINING_MACROS then []
          else symbol_values.take(1)
          end
        end

        def symbol_values
          node.arguments.select(&:sym_type?).map(&:value)
        end

        def lambda_argument_calls
          node.arguments.select(&:block_type?).flat_map { receiverless_method_names_in(it.body) }
        end
    end
end
