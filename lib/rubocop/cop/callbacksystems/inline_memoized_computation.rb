# Detects memoization methods that delegate to another method in the same class.
# The second method exists only to serve the first, so the reading is split
# across two definitions for nothing, and the computation belongs in the method
# that caches it.
#
# @example
#   # bad - delegates to another method
#   def user
#     @user ||= find_user
#   end
#
#   private
#     def find_user
#       User.find(params[:id])
#     end
#
#   # good - computation is inline
#   def user
#     @user ||= User.find(params[:id])
#   end
#
#   # good - calls a method on a receiver (not delegation)
#   def owner
#     @owner ||= account.owner
#   end
#
#   # good - calls method with arguments
#   def formatted_name
#     @formatted_name ||= format_name(first, last)
#   end
#
#   # good - has additional logic
#   def user
#     @user ||= find_user || default_user
#   end
#
class RuboCop::Cop::Callbacksystems::InlineMemoizedComputation < RuboCop::Cop::Callbacksystems::Base
  def on_new_investigation
    @method_calls = RuboCop::Callbacksystems::Methods::Calls.new(processed_source.ast)
    @sibling_methods = RuboCop::Callbacksystems::Methods::Siblings.new
    @macro_referenced_methods = RuboCop::Callbacksystems::Methods::MacroReferences::ContainerIndex.new
  end

  def on_def(node)
    report Memoization.new(node, method_calls:, sibling_methods:, macro_referenced_methods:)
  end

  alias on_defs on_def

  private
    attr_reader :macro_referenced_methods, :method_calls, :sibling_methods

    class Memoization
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Inline the computation from `%<method>s` instead of delegating."

      def initialize(node, method_calls:, sibling_methods:, macro_referenced_methods:)
        @node = node
        @method_calls = method_calls
        @sibling_methods = sibling_methods
        @macro_referenced_methods = macro_referenced_methods
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if delegates_to_own_method?
      end

      private
        attr_reader :node, :method_calls, :sibling_methods, :macro_referenced_methods
        delegate :expression, to: "node.body", private: true

        def delegates_to_own_method?
          node.body&.or_asgn_type? && delegating_call? && private_delegated_definition? && sole_call_site? &&
            !macro_referenced?
        end

        def delegating_call?
          bare_send?(expression) && expression.arguments.empty?
        end

        def private_delegated_definition?
          delegated_definition && private_method?(delegated_definition)
        end

        def delegated_definition
          @delegated_definition ||= sibling_methods.named(delegated_method, beside: node).first
        end

        def delegated_method
          expression.method_name
        end

        def sole_call_site?
          calls_to_delegated_method.one? && calls_to_delegated_method.first.equal?(expression)
        end

        def calls_to_delegated_method
          @calls_to_delegated_method ||= method_calls.named(delegated_method, from: node)
        end

        def macro_referenced?
          macro_referenced_methods.include?(delegated_method, beside: node)
        end

        def message
          format(MESSAGE, method: delegated_method)
        end
    end
end
