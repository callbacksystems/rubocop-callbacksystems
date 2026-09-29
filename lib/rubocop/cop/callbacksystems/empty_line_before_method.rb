# Enforces an empty line before method definitions. The empty line is what
# separates one definition from the next when reading down a class, so a method
# pressed against a macro or the method above reads as a continuation of it.
#
# @example
#   # bad - macro directly before method
#   before_action :authenticate
#   def index
#   end
#
#   # bad - consecutive methods without empty line
#   def name
#   end
#   def email
#   end
#
#   # good - empty line before method
#   before_action :authenticate
#
#   def index
#   end
#
#   # good - empty line between methods
#   def name
#   end
#
#   def email
#   end
#
#   # good - consecutive macros are fine
#   validates :name
#   validates :email
#
#   # good - first method in class body needs no preceding empty line
#   class User
#     def name
#     end
#   end
#
#   # good - method after visibility modifier needs no empty line
#   private
#     def helper
#     end
#
class RuboCop::Cop::Callbacksystems::EmptyLineBeforeMethod < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_def(node)
    report MethodDefinition.new(node, describing_macros)
  end

  alias on_defs on_def

  private
    def describing_macros
      Array(cop_config["DescribingMacros"]).map(&:to_sym)
    end

    class MethodDefinition
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Add an empty line before `%<method>s`."

      def initialize(node, describing_macros)
        @node = node
        @describing_macros = describing_macros
      end

      def offense
        if crowded?
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: source_ordered?) { correct(it) }
        end
      end

      private
        attr_reader :node, :describing_macros
        delegate :adjacent_to_previous?, :leading_node, :previous_node, to: :description_group, private: true

        def description_group
          @description_group ||= DescriptionGroup.new(node, describing_macros)
        end

        def crowded?
          previous_node && !after_visibility_modifier? && missing_empty_line?
        end

        def after_visibility_modifier?
          !visibility_modifier_of(previous_node).nil?
        end

        def missing_empty_line?
          adjacent_to_previous?
        end

        def message
          format(MESSAGE, method: node.method_name)
        end

        def source_ordered?
          range_through_heredocs(previous_node).end_pos <= leading_node.source_range.begin_pos
        end

        def correct(corrector)
          if previous_node.last_line == leading_node.first_line
            corrector.replace \
              previous_node.source_range.end.join(leading_node.source_range.begin),
              "\n\n#{indentation_of(previous_node)}"
          else
            corrector.insert_before(line_start_of(leading_node), "\n")
          end
        end

        def line_start_of(statement)
          position = line_start_position_of(statement)
          statement.source_range.with(begin_pos: position, end_pos: position)
        end

        # The consecutive describing macros attached to a method and the statement immediately before that group.
        class DescriptionGroup
          include RuboCop::Callbacksystems::Helpers

          def initialize(node, describing_macros)
            @node = node
            @describing_macros = describing_macros
          end

          def adjacent_to_previous?
            previous_node && adjacent?(above: previous_node, below: leading_node)
          end

          def previous_node
            siblings[leading_position.pred] if leading_position.positive?
          end

          def leading_node
            siblings.fetch(leading_position)
          end

          private
            attr_reader :node, :describing_macros

            def leading_position
              @leading_position ||= node_position.downto(1).find { !joins_description_at?(it) } || 0
            end

            def node_position
              @node_position ||= siblings.index(node)
            end

            def siblings
              @siblings ||= node.parent&.begin_type? ? node.parent.child_nodes : [ node ]
            end

            def joins_description_at?(position)
              above = siblings.fetch(position.pred)
              describing?(above) && adjacent?(above:, below: siblings.fetch(position))
            end

            def describing?(statement)
              bare_send?(statement) && describing_macros.include?(statement.method_name)
            end

            def adjacent?(above:, below:)
              (below.first_line - range_through_heredocs(above).last_line) <= 1
            end
        end
    end
end
