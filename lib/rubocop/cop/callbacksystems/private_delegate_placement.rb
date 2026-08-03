# `delegate ... private: true` declares private methods, so it belongs in the private section next to the other private
# declarations. Left above, it hides private methods among the public API; left below the section's methods, it hides a
# declaration among behavior.
#
# @example
#   # bad
#   class Report
#     delegate :total, to: :order, private: true
#
#     def to_s
#       total.to_s
#     end
#
#     private
#       attr_reader :order
#   end
#
#   # bad - below the methods of its section
#   class Report
#     private
#       def formatted_total
#         total.to_s
#       end
#
#       delegate :total, to: :order, private: true
#   end
#
#   # good
#   class Report
#     def to_s
#       total.to_s
#     end
#
#     private
#       attr_reader :order
#       delegate :total, to: :order, private: true
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateDelegatePlacement < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Move this `delegate` into the private section; it declares private methods."
  STRAYED_MESSAGE = "Move this `delegate` up beside the other private declarations."

  def on_send(node)
    delegation = MisplacedDelegate.new(node)
    add_offense(node, message: delegation.offense_message) { delegation.move(it) } if delegation.offense?
  end

  alias on_csend on_send

  private
    class MisplacedDelegate
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        private_delegate? && statements.include?(node) && !placed_with_declarations? && !blocked_by_constant?
      end

      def offense_message
        outside_private_section? ? MESSAGE : STRAYED_MESSAGE
      end

      def move(corrector)
        corrector.insert_after(anchor, relocated_delegate)
        corrector.remove(statement_removal_range_for(node))
      end

      private
        attr_reader :node

        def private_delegate?
          macro.macro? && macro.private?
        end

        def macro
          @macro ||= RuboCop::Callbacksystems::DelegateMacro.new(node)
        end

        def statements
          @statements ||= statements_in(enclosing_body)
        end

        def enclosing_body
          @enclosing_body ||= enclosing_body_for(node)
        end

        def placed_with_declarations?
          declarations_after_private_modifier.include?(node)
        end

        def declarations_after_private_modifier
          statements_after_private_modifier.take_while { declaration?(it) }
        end

        def statements_after_private_modifier
          private_modifier ? statements.drop(statements.index(private_modifier) + 1) : []
        end

        def private_modifier
          @private_modifier ||= private_modifier_in(enclosing_body)
        end

        def declaration?(statement)
          statement.casgn_type? || declaration_macro?(statement)
        end

        # Moving above a constant it reads would break the class at load time.
        def blocked_by_constant?
          referenced_constant_names.intersect?(constant_names_crossed_moving_up)
        end

        def referenced_constant_names
          node.arguments.flat_map { it.each_node(:const).map(&:short_name) }
        end

        def constant_names_crossed_moving_up
          statements_between_anchor_and_node.select(&:casgn_type?).map(&:name)
        end

        def statements_between_anchor_and_node
          anchor_index = statements.index(anchor)
          node_index = statements.index(node)
          anchor_index && anchor_index < node_index ? statements[(anchor_index + 1)...node_index] : []
        end

        def anchor
          declarations_after_private_modifier.last || private_modifier || statements.excluding(node).last
        end

        def outside_private_section?
          visibility_at(node, enclosing_body) != :private
        end

        def relocated_delegate
          private_modifier ? indented_delegate : "\n\n#{body_indentation}private#{indented_delegate}"
        end

        def indented_delegate
          "\n#{section_indentation}#{node.source}"
        end

        # Members sit one step deeper than `private`, so an existing one says how deep.
        def section_indentation
          statements_after_private_modifier.first&.then { indentation_of(it) } || "#{body_indentation}#{indentation_step}"
        end

        def body_indentation
          indentation_of(statements.first)
        end

        def indentation_step
          " " * (statements.first.source_range.column - enclosing_definition_of(node).source_range.column)
        end
    end
end
