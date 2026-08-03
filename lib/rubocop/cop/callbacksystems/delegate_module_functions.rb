# Detects methods that only wrap the same-named method on a constant.
# `delegate` declares the relationship in one line.
#
# A wrapper that forwards its own parameters is replaced verbatim, so it is
# autocorrected; PrivateDelegatePlacement then moves the resulting line beside
# the other declarations. A wrapper that supplies arguments from its own state
# changes arity when delegated, so every call site must start passing the
# arguments and the offense is only reported.
#
# @example
#   # bad - autocorrected to `delegate :subunit_factor, to: Currency, private: true`
#   private
#     def subunit_factor(currency)
#       Currency.subunit_factor(currency)
#     end
#
#   # bad - callers must pass the argument: subunit_factor(options[:currency])
#   def subunit_factor
#     Currency.subunit_factor(options[:currency])
#   end
#
#   # good
#   delegate :subunit_factor, to: Currency
#
#   # good - a public method forwarding its own parameters is Rails/Delegate's territory
#   def subunit_factor(currency)
#     Currency.subunit_factor(currency)
#   end
#
class RuboCop::Cop::Callbacksystems::DelegateModuleFunctions < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Method `%<method>s` only wraps `%<target>s.%<method>s`. Use `delegate :%<method>s, to: %<target>s%<options>s`%<arguments_note>s."

  # @!method wrapped_constant_call?(node)
  def_node_matcher :wrapped_constant_call?, <<~PATTERN
    (def _name _args (send (const ...) _name ...))
  PATTERN

  def on_def(node)
    if wrapped_constant_call?(node)
      delegation = ConstantDelegation.new(node, processed_source.comments)
      if delegation.correctable?
        add_offense(node, message: delegation.offense_message) { delegation.replace(it) }
      elsif delegation.offense?
        add_offense(node, message: delegation.offense_message)
      end
    end
  end

  private
    class ConstantDelegation
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
        @visibility = RuboCop::Callbacksystems::NodeVisibility.new(node)
      end

      # A one-line `delegate` has nowhere to put a comment from the method body.
      def correctable?
        offense? && forwards_own_parameters? && !holds_comment?(node.source_range, comments)
      end

      def offense?
        visibility.private? || (visibility.public? && !forwards_own_parameters?)
      end

      def replace(corrector)
        corrector.replace(node, delegate_line)
      end

      def offense_message
        format MESSAGE,
          method: node.method_name,
          target: target.source,
          options: private_option,
          arguments_note: forwards_own_parameters? ? "" : " and pass the arguments at the call sites"
      end

      private
        attr_reader :node, :comments, :visibility

        def forwards_own_parameters?
          node.body.arguments.map(&:source) == node.arguments.map(&:source)
        end

        def delegate_line
          "delegate :#{node.method_name}, to: #{target.source}#{private_option}"
        end

        def target
          node.body.receiver
        end

        def private_option
          visibility.private? ? ", private: true" : ""
        end
    end
end
