module RuboCop::Callbacksystems::Helpers::Builders
  SELF_REBINDING_METHODS = %i[ instance_eval instance_exec class_eval class_exec module_eval module_exec ]

  def self_preserved_between?(node, boundary:)
    SelfPreservation.new(node, boundary:).preserved?
  end

  def self_rebinding_boundary?(node)
    SelfBoundary.new(node).rebinds?
  end

  def nested_body?(node)
    class_with_body?(node) || module_with_body?(node)
  end

  def class_with_body?(node)
    node.class_type? ? node.body.present? : builder_assignment_for(node).builds_class_with_body?
  end

  def module_with_body?(node)
    node.module_type? ? node.body.present? : builder_assignment_for(node).builds_module_with_body?
  end

  private
    def builder_assignment_for(node)
      RuboCop::Callbacksystems::ClassStructure::BuilderAssignment.new(node)
    end

    # Whether one node keeps its lexical self before reaching a caller-selected boundary.
    class SelfPreservation
      def initialize(node, boundary:)
        @node = node
        @boundary = boundary
      end

      def preserved?
        ancestors.none? { SelfBoundary.new(it, descendant: node).rebinds_around_descendant? }
      end

      private
        attr_reader :node, :boundary

        def ancestors
          node.each_ancestor.take_while { !it.equal?(boundary) }
        end
    end

    # A lexical construct or block whose body observes a self other than the surrounding expression.
    class SelfBoundary
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, descendant: nil)
        @node = node
        @descendant = descendant
      end

      def rebinds_around_descendant?
        rebinds? && rebound_parts.any? { contains_descendant?(it) }
      end

      def rebinds?
        lexical_definition?(node) || (any_block_type?(node) && self_rebinding_block?)
      end

      private
        attr_reader :node, :descendant

        def self_rebinding_block?
          method_definition_block?(node) || self_rebinding_builder? || self_rebinding_evaluator?
        end

        def self_rebinding_builder?
          core_constant?(block_call.receiver) &&
            builder_method_for(block_call.receiver.short_name) == block_call.method_name
        end

        def block_call
          @block_call ||= call_of(node)
        end

        def builder_method_for(name)
          RuboCop::Callbacksystems::ClassStructure::BuilderAssignment::CLASS_BUILDERS[name] ||
            RuboCop::Callbacksystems::ClassStructure::BuilderAssignment::MODULE_BUILDERS[name]
        end

        def self_rebinding_evaluator?
          block_call.receiver && !block_call.receiver.self_type? &&
            SELF_REBINDING_METHODS.include?(block_call.method_name)
        end

        def rebound_parts
          if any_block_type?(node) || node.any_def_type?
            [ node.arguments, node.body ].compact
          else
            [ node.body ].compact
          end
        end

        def contains_descendant?(part)
          part.equal?(descendant) || part.source_range&.contains?(descendant.source_range)
        end
    end
end
