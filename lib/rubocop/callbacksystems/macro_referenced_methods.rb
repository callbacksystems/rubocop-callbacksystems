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

  # In source order, so a caller can order these methods the way the macros mention them.
  def ordered
    collect(body).uniq
  end

  private
    attr_reader :body

    # Method bodies are skipped: an ordinary symbol argument in one is not a macro.
    def collect(node)
      if node.is_a?(RuboCop::AST::Node) && !node.type?(:def, :defs)
        Node.new(node).references + node.children.flat_map { collect(it) }
      else
        []
      end
    end

    class Node
      include RuboCop::Callbacksystems::Helpers

      # Options whose symbol names a method: a callback guard, a `rescue_from` handler.
      METHOD_OPTIONS = %i[if unless with].freeze

      # Their leading symbol names what they declare, not a method the class calls: an accessor, an association, a
      # queue, a token purpose.
      DECLARING_MACROS = %i[
        attr_reader attr_writer attr_accessor
        mattr_reader mattr_writer mattr_accessor
        cattr_reader cattr_writer cattr_accessor
        thread_mattr_accessor thread_cattr_accessor
        attribute class_attribute store_accessor delegate define_method
        belongs_to has_and_belongs_to_many has_many has_one
        has_many_attached has_one_attached has_rich_text
        has_secure_password has_secure_token generates_token_for
        composed_of enum scope queue_as
      ].freeze

      # These name what they define first and what they call second.
      ALIASING_MACROS = %i[alias_attribute alias_method].freeze

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

        # A guard runs before the action it guards, so it comes first.
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

        def symbol_argument_reference
          case node.method_name
          when *ALIASING_MACROS then symbol_values.drop(1).take(1)
          when *DECLARING_MACROS then []
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
