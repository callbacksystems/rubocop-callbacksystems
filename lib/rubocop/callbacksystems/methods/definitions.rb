class RuboCop::Callbacksystems::Methods::Definitions
  include Enumerable
  include RuboCop::Callbacksystems::Helpers

  delegate :each, to: :definitions

  def initialize(ast)
    @ast = ast
  end

  private
    Definition = Data.define(:node, :name)

    attr_reader :ast

    def definitions
      bodies = top_level_definitions_in(ast).map { Body.new(it.body, depth: 0, context: :owner) }

      Traversal.new(bodies).to_a
    end

    # Definition-bearing body and statement entries walked depth first without recursive object calls.
    class Traversal
      include Enumerable

      def initialize(entries)
        @entries = entries
      end

      def each
        if block_given?
          pending = entries.reverse
          until pending.empty?
            entry = pending.pop
            entry.definitions.each { yield it }
            pending.concat(entry.children.reverse)
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :entries
    end

    class Body
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, depth:, context:, singleton_owner_body: nil)
        @node = node
        @depth = depth
        @context = context
        @singleton_owner_body = singleton_owner_body
      end

      def definitions
        []
      end

      def children
        statements_in(node).map { Statement.new(it, body: self) }
      end

      def public_definition?(definition)
        DefinitionVisibility.new(definition, node, singleton_owner_body:).public?
      end

      def target_definition?(definition)
        depth_of(definition) <= 1
      end

      def target_scope?
        depth.zero?
      end

      def body_within_singleton_section(child)
        if depth.zero?
          self.class.new(child, depth: 1, context: :singleton, singleton_owner_body: node)
        end
      end

      def body_within_definition_block(child, kind:)
        unless context == :singleton
          self.class.new(child, depth: kind == :class_methods ? 1 : 0, context: :definition_block)
        end
      end

      private
        attr_reader :node, :depth, :context, :singleton_owner_body

        def depth_of(definition)
          depth + (definition.defs_type? ? 1 : 0)
        end

        class DefinitionVisibility
          include RuboCop::Callbacksystems::Helpers

          def initialize(definition, body, singleton_owner_body:)
            @definition = definition
            @body = body
            @singleton_owner_body = singleton_owner_body
          end

          def public?
            level == :public
          end

          private
            attr_reader :definition, :body, :singleton_owner_body

            def level
              if definition.location
                assigned_level || visibility_applied_to(definition.parent, definition) || default_level
              else
                :public
              end
            end

            def assigned_level
              assignments.max_by(&:position)&.level
            end

            def assignments
              [
                visibility.assignment_after(definition, singleton: definition.defs_type?),
                singleton_owner_visibility&.assignment_after(definition, singleton: true)
              ].compact
            end

            def visibility
              @visibility ||= RuboCop::Callbacksystems::ClassStructure::Visibility.for(body)
            end

            def singleton_owner_visibility
              if singleton_owner_body
                RuboCop::Callbacksystems::ClassStructure::Visibility.for(singleton_owner_body)
              end
            end

            def default_level
              definition.defs_type? ? :public : visibility.level_at(definition)
            end
        end
    end

    class Statement
      include RuboCop::Callbacksystems::Helpers

      DEFINITION_BLOCKS = %i[ class_methods included prepended ].to_set

      def initialize(node, body:)
        @node = node
        @body = body
      end

      def definitions
        explicit_definitions + scope_entry
      end

      def children
        if singleton_section?(node)
          singleton_body.then { [ it ].compact }
        elsif known_definition_block?
          definition_block_body.then { [ it ].compact }
        else
          []
        end
      end

      private
        attr_reader :node, :body

        def explicit_definitions
          method_definitions.filter_map do |definition|
            if owned_definition?(definition) && body.public_definition?(definition)
              Definition.new(definition, definition.method_name)
            end
          end
        end

        def method_definitions
          if node.any_def_type?
            [ node ]
          elsif node.call_type?
            node.arguments.select(&:any_def_type?)
          else
            []
          end
        end

        def owned_definition?(definition)
          body.target_definition?(definition) && (!definition.defs_type? || definition.receiver.self_type?)
        end

        def scope_entry
          call = call_of(node)

          if body.target_scope? && scope_definition?(call)
            [ Definition.new(call, call.first_argument.value) ]
          else
            []
          end
        end

        def singleton_body
          body.body_within_singleton_section(node.body)
        end

        def known_definition_block?
          any_block_type?(node) && call_on_self?(call_of(node)) && DEFINITION_BLOCKS.include?(node.method_name)
        end

        def definition_block_body
          body.body_within_definition_block(node.body, kind: node.method_name)
        end
    end
end
