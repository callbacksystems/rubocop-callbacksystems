class RuboCop::Callbacksystems::Methods::MacroReferences
  include Enumerable
  include RuboCop::Callbacksystems::Helpers

  delegate :each, to: :names_in_source_order

  def initialize(body)
    @body = body
  end

  private
    attr_reader :body

    def names_in_source_order
      @names_in_source_order ||= References.new(body).to_a.uniq
    end

    # References in one lexical owner, with method bodies skipped and nested class domains pruned.
    class References
      include Enumerable

      def initialize(body)
        @body = body
      end

      def each
        if block_given?
          pending = [ Visit.new(body, block_calls_collected: false) ]
          until pending.empty?
            visit = pending.pop
            unless visit.boundary?
              visit.method_names.each { yield it }
              pending.concat(visit.children.reverse)
            end
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :body

        class Visit
          include RuboCop::Callbacksystems::Helpers

          def initialize(node, block_calls_collected:)
            @node = node
            @block_calls_collected = block_calls_collected
          end

          def boundary?
            node.nil? || node.type?(:def, :defs, :class, :module, :sclass)
          end

          def method_names
            if any_block_type?(node)
              block_calls_collected ? [] : BlockCalls.new(node.body).to_a
            else
              Statement.new(node).references
            end
          end

          def children
            node.each_child_node.map do |child|
              self.class.new(child, block_calls_collected: block_calls_collected || any_block_type?(node))
            end
          end

          private
            attr_reader :node, :block_calls_collected
        end
    end

    # Receiverless calls in the first block of a nested block tree, including its method definitions as before.
    class BlockCalls
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(body)
        @body = body
      end

      def each
        if block_given?
          pending = [ body ].compact
          until pending.empty?
            node = pending.pop
            unless node.type?(:class, :module, :sclass)
              yield node.method_name if bare_send?(node)
              pending.concat(node.each_child_node.to_a.reverse)
            end
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :body
    end

    class Statement
      include RuboCop::Callbacksystems::Helpers

      CALLBACK_OPTIONS = %i[ if unless ]

      # Unknown class macros can take symbols as data (`validates :name`), so only these known callbacks let a
      # positional symbol make a method look referenced.
      METHOD_REFERENCE_MACROS = %i[
        after_action after_commit after_create after_create_commit after_destroy after_destroy_commit
        after_deliver after_discard after_enqueue after_find after_initialize after_perform after_rollback
        after_save after_save_commit after_touch after_update after_update_commit after_validation before_action
        before_commit before_create before_deliver before_destroy before_enqueue before_perform before_save
        before_update before_validation around_action around_create around_deliver around_destroy around_enqueue
        around_perform around_save around_update append_after_action append_around_action append_before_action
        helper_method prepend_after_action prepend_around_action prepend_before_action rescue_from setup
        skip_after_action skip_around_action skip_before_action teardown validate
      ]
      CALLBACK_CONFIGURATION_MACROS = %i[ set_callback skip_callback ]

      # `delegate` defines its leading names as the accessors do, and its `to:` target still counts through the options.
      DEFINING_MACROS = %i[
        attr_reader attr_writer attr_accessor
        mattr_reader mattr_writer mattr_accessor
        cattr_reader cattr_writer cattr_accessor
        thread_mattr_accessor thread_cattr_accessor
        class_attribute store_accessor attribute delegate
      ]

      def initialize(node)
        @node = node
      end

      def references
        node.send_type? ? from_send : []
      end

      private
        attr_reader :node

        # A callback's `if:`/`unless:` runs before the action it guards, so the hash options lead.
        def from_send
          hash_option_references + symbol_arguments + lambda_argument_calls
        end

        def hash_option_references
          hash_pairs_of(node).flat_map { OptionReference.new(node, it).to_a }
        end

        def symbol_arguments
          if CALLBACK_CONFIGURATION_MACROS.include?(node.method_name)
            configured_callback_arguments
          elsif METHOD_REFERENCE_MACROS.include?(node.method_name) && DEFINING_MACROS.exclude?(node.method_name)
            node.arguments.select(&:sym_type?).map(&:value)
          else
            []
          end
        end

        # The event and timing in `set_callback :save, :before, :normalize` are data; only the remaining filters name
        # methods.
        def configured_callback_arguments
          node.arguments.drop(2).select(&:sym_type?).map(&:value)
        end

        def lambda_argument_calls
          node.arguments.select { any_block_type?(it) }.flat_map { receiverless_method_names_in(it.body) }
        end

        # One callback option read as the method names its key and value can reference.
        class OptionReference
          include RuboCop::Callbacksystems::Helpers

          def initialize(macro, pair)
            @macro = macro
            @key = pair.key
            @value = pair.value
          end

          def to_a
            if key.sym_type?
              case key.value
              when :to then delegate_target
              when *CALLBACK_OPTIONS then callback_condition
              when :with then rescue_handler
              else []
              end
            else
              []
            end
          end

          private
            attr_reader :macro, :key, :value

            def delegate_target
              case value.type
              when :sym then [ value.value ]
              when :str then Array(value.value.split(".").first&.to_sym)
              else []
              end
            end

            def callback_condition
              if value.sym_type?
                [ value.value ]
              elsif any_block_type?(value)
                receiverless_method_names_in(value.body)
              else
                []
              end
            end

            def rescue_handler
              macro.method?(:rescue_from) && value.sym_type? ? [ value.value ] : []
            end
        end
    end

    class ContainerIndex
      def initialize
        @by_container = {}.compare_by_identity
      end

      def include?(name, beside:)
        container = RuboCop::Callbacksystems::Methods::Domain.new(beside).container
        container && references_in(container).include?(name)
      end

      private
        attr_reader :by_container

        def references_in(container)
          by_container[container] ||= RuboCop::Callbacksystems::Methods::MacroReferences.new(container.body).to_set
        end
    end
end
