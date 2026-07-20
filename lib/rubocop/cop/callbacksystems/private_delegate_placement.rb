# `delegate ... private: true` declares private methods, so it belongs in the
# private section next to the other private declarations. Left above, it hides
# private methods among the public API.
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

  def on_send(node)
    delegation = MisplacedDelegate.new(node)
    add_offense(node, message: MESSAGE) { delegation.move(it) } if delegation.offense?
  end

  alias on_csend on_send

  private
    class MisplacedDelegate
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        private_delegate? && outside_private_section?
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

        def outside_private_section?
          statements.include?(node) && visibility_at(node, enclosing_body) != :private
        end

        def statements
          @statements ||= statements_in(enclosing_body)
        end

        def enclosing_body
          @enclosing_body ||= enclosing_body_for(node)
        end

        # Beside the private declarations when the section is already open,
        # otherwise at the end of the body, where the new section goes.
        def anchor
          declarations_after_private_modifier.last || private_modifier || statements.excluding(node).last
        end

        def declarations_after_private_modifier
          statements_after_private_modifier.take_while { declaration_macro?(it) }
        end

        def statements_after_private_modifier
          private_modifier ? statements.drop(statements.index(private_modifier) + 1) : []
        end

        def private_modifier
          @private_modifier ||= private_modifier_in(enclosing_body)
        end

        def relocated_delegate
          private_modifier ? indented_delegate : "\n\n#{body_indentation}private#{indented_delegate}"
        end

        def indented_delegate
          "\n#{section_indentation}#{node.source}"
        end

        # The section's members sit one step deeper than the `private` keyword,
        # so an existing member is what says how deep that is.
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
