# Detects local variables that just alias a method call.
# Call the method directly or extract a well-named declarative method instead.
#
# @example
#   # bad - variable just aliases a method call
#   directory = forbidden_directory
#   add_offense(node) if directory
#
#   # good - call the method directly
#   add_offense(node) if forbidden_directory
#
#   # ok - variable used multiple times
#   user = find_user
#   user.activate
#   user.notify
#
#   # ok - variable used inside a block (may be mutated across iterations)
#   result = Set.new
#   items.each { |item| result << item }
#
#   # ok - assignment in conditional
#   if user = find_user
#     user.activate
#   end
#
#   # ok - variable reassigned
#   current = first
#   current = current.next while current
#
class RuboCop::Cop::Callbacksystems::UnnecessaryLocalVariable < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Variable `%<name>s` is unnecessary. Call the method directly or extract a well-named declarative method."

  def on_lvasgn(node)
    return unless Assignment.new(node).unnecessary?

    add_offense(node, message: format(MESSAGE, name: node.children.first))
  end

  private
    class Assignment
      def initialize(node)
        @node = node
        @variable_name = node.children.first
        @value = node.children.second
      end

      def unnecessary?
        method_call_value? && !conditional? && single_use? && !used_inside_nested_block? && !used_for_restoration?
      end

      private
        attr_reader :node, :variable_name, :value

        def method_call_value?
          value&.type?(:call)
        end

        def conditional?
          node.each_ancestor(:if, :while, :until, :case, :and, :or).any?
        end

        def single_use?
          enclosing_scope && !reassigned? && references.size == 1
        end

        def used_inside_nested_block?
          references.first.each_ancestor(:any_block).any? { it != enclosing_scope }
        end

        def used_for_restoration?
          references.first.each_ancestor(:ensure, :resbody).any?
        end

        def enclosing_scope
          @enclosing_scope ||= node.each_ancestor(:any_def, :any_block).first
        end

        def references
          @references ||= other_occurrences.select(&:lvar_type?)
        end

        def reassigned?
          other_occurrences.any?(&:lvasgn_type?)
        end

        def other_occurrences
          @other_occurrences ||= enclosing_scope.each_descendant(:lvar, :lvasgn).select do |descendant|
            descendant.children.first == variable_name && descendant != node
          end
        end
    end
end
