# A `private` keyword with nothing after it declares a section that holds nothing. Remove it and let the class end where
# it ends.
#
# @example
#   # bad
#   class Order
#     def total
#     end
#
#     private
#   end
#
#   # good
#   class Order
#     def total
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::EmptyPrivateSection < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Remove the empty `private` section."

  def on_send(node)
    section = PrivateSection.new(node)
    add_offense(node, message: MESSAGE) { section.remove(it) } if section.empty?
  end

  alias on_csend on_send

  private
    class PrivateSection
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def empty?
        private_modifier? && closes_enclosing_body?
      end

      def remove(corrector)
        corrector.remove(statement_removal_range_for(node))
      end

      private
        attr_reader :node

        def private_modifier?
          visibility_modifier_of(node) == :private
        end

        def closes_enclosing_body?
          statements_in(enclosing_body).last.equal?(node)
        end

        # Not `enclosing_body_for`, which only reports multi-statement bodies.
        def enclosing_body
          enclosing_definition_of(node)&.body
        end
    end
end
