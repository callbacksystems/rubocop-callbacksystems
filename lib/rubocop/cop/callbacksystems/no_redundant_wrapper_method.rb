# Detects private methods that only call another method or read a constant
# without adding value. Such a wrapper is one more name for a reader to
# resolve on the way to the thing it stands for, and it hides the call site
# from whoever searches for the method it wraps. Public methods and predicates
# are excluded as they often provide semantic value.
#
# @example
#   # bad - private wrapper just calls another method
#   private
#     def find_all
#       find(@node)
#     end
#
#   # bad - private wrapper carries the name of the constant it reads
#   MESSAGE = "Remove this."
#
#   private
#     def message
#       MESSAGE
#     end
#
#   # good - read the constant where it is needed
#   MESSAGE = "Remove this."
#
#   private
#     def offense
#       Offense.new(node, MESSAGE)
#     end
#
#   # good - the method names a concept, and a subclass answers with its own constant
#   private
#     def marker_tag
#       DEFAULT_MARKER_TAG
#     end
#
#   # good - nothing in the class calls it, so a superclass or a subclass does
#   private
#     def path_after_saving
#       root_path
#     end
#
#   # good - read from several places, so it is the one spelling of that value
#   private
#     def scope
#       account.widgets
#     end
#
#   # good - public method (may be API or provide semantic meaning)
#   def authenticated?
#     resume_session
#   end
#
#   # good - predicate provides semantic alias
#   def fulfillable?
#     paid?
#   end
#
#   # good - method does something meaningful
#   def find_all
#     find(@node).compact
#   end
#
class RuboCop::Cop::Callbacksystems::NoRedundantWrapperMethod < RuboCop::Cop::Callbacksystems::Base
  def on_new_investigation
    @method_calls = RuboCop::Callbacksystems::Methods::Calls.new(processed_source.ast)
    @macro_referenced_methods = RuboCop::Callbacksystems::Methods::MacroReferences::ContainerIndex.new
  end

  def on_def(node)
    if private_non_predicate?(node)
      report WrapperMethod.new(node, method_calls:, macro_referenced_methods:)
    end
  end

  alias on_defs on_def

  private
    attr_reader :macro_referenced_methods, :method_calls

    class WrapperMethod
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method `%<wrapper>s` only wraps `%<target>s` without adding value. Consider removing the indirection."

      def initialize(node, method_calls:, macro_referenced_methods:)
        @node = node
        @method_calls = method_calls
        @macro_referenced_methods = macro_referenced_methods
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if redundant? && inlineable?
      end

      private
        attr_reader :node, :method_calls, :macro_referenced_methods
        delegate :body, to: :node, private: true

        def redundant?
          wraps_a_call? || reads_a_constant?
        end

        def wraps_a_call?
          body&.send_type? && simple_method_call? && arguments_are_pass_through?
        end

        def simple_method_call?
          body.receiver.nil? || body.receiver.self_type?
        end

        def arguments_are_pass_through?
          body.arguments.all? { passes_through?(it) }
        end

        def passes_through?(argument)
          argument.ivar_type? || parameter_names_of(node).include?(spelling_of(argument))
        end

        def spelling_of(argument)
          argument.lvar_type? ? argument.name.to_s : argument.source
        end

        def reads_a_constant?
          body&.const_type? && node.arguments.empty? && named_after_the_constant?
        end

        # A method naming the constant something else states a concept, usually a hook a subclass answers with its own.
        def named_after_the_constant?
          node.method_name.to_s.upcase == body.short_name.to_s
        end

        def inlineable?
          called_in_its_class? && !sole_spelling_of_a_value? && !macro_referenced?
        end

        # A private method nothing in its class calls is the hook a superclass or a subclass answers.
        def called_in_its_class?
          calls.any?
        end

        def calls
          @calls ||= method_calls.named(node.method_name, from: node)
        end

        def sole_spelling_of_a_value?
          node.arguments.empty? && calls.many?
        end

        def macro_referenced?
          macro_referenced_methods.include?(node.method_name, beside: node)
        end

        def message
          format(MESSAGE, wrapper: node.method_name, target: target)
        end

        def target
          body.const_type? ? body.source : body.method_name
        end
    end
end
