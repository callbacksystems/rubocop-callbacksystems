# Detects methods that only delegate to a same-named method on a plain receiver (`def size; node.size; end`). The
# `delegate` macro says it declaratively.
#
# Rails/Delegate covers the public single-receiver case, so what is left here is the private one (the macro defines
# public methods unless told otherwise) and the nested one, where a chain of calls becomes a dotted target that
# Rails/Delegate does not recognize.
#
# The autocorrection folds the method into an existing same-target `delegate` when one is present, keeping them on one
# line; otherwise it writes a fresh macro beside the section's other declarations.
#
# @example
#   # bad - hand-written private delegation
#   private
#     delegate :name, to: :node, private: true
#
#     def size
#       node.size
#     end
#
#   # good - folded into the existing delegate
#   private
#     delegate :name, :size, to: :node, private: true
#
#   # bad - hand-written nested delegation
#   def database_names
#     config.postgres.database_names
#   end
#
#   # good - the chain becomes a dotted target
#   delegate :database_names, to: "config.postgres"
#
class RuboCop::Cop::Callbacksystems::PreferDelegate < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use the `delegate` macro instead of a hand-written delegation to `%<receiver>s`."

  def on_def(node)
    delegation = ManualDelegation.new(node, processed_source.comments)
    add_offense(node, message: delegation.offense_message) { delegation.correct(it) } if delegation.offense?
  end

  private
    class ManualDelegation
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def offense?
        node.arguments.empty? && delegates_to_same_name? && reportable?
      end

      def offense_message
        format(MESSAGE, receiver: receiver_names.join("."))
      end

      # A one-line `delegate` has nowhere to put a comment from the method body.
      def correct(corrector)
        Conversion.new(node, receiver_names).apply(corrector) unless holds_comment?(node.source_range, comments)
      end

      private
        attr_reader :node, :comments
        delegate :body, to: :node, private: true

        def delegates_to_same_name?
          body&.send_type? && body.method?(node.method_name) && body.arguments.empty? && receiver_names.any?
        end

        def receiver_names
          @receiver_names ||= chain_names_in(body&.receiver) || []
        end

        # Anything but a chain of argumentless calls on self gives up the whole reading.
        def chain_names_in(receiver)
          if receiver.nil?
            []
          elsif chained_call?(receiver)
            chain_names_in(receiver.receiver)&.then { it + [ receiver.method_name ] }
          end
        end

        def chained_call?(receiver)
          receiver.send_type? && receiver.arguments.empty?
        end

        # Rails/Delegate already reports the public single-receiver case.
        def reportable?
          private_method?(node) || receiver_names.many?
        end
    end

    # With no declaration and no `private` to anchor the macro, the offense is reported without a correction.
    class Conversion
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, receiver_names)
        @node = node
        @receiver_names = receiver_names
      end

      def apply(corrector)
        if sibling_delegate || anchor
          write(corrector)
          corrector.remove(statement_removal_range_for(node))
        end
      end

      private
        attr_reader :node, :receiver_names

        def sibling_delegate
          @sibling_delegate ||= container_macros.find { sibling?(it) }
        end

        def container_macros
          container_statements.map { RuboCop::Callbacksystems::DelegateMacro.new(it) }
        end

        def container_statements
          statements_in(enclosing_body_for(node))
        end

        def sibling?(macro)
          macro.macro? && macro.target == receiver_path && macro.private? == private_delegation?
        end

        def receiver_path
          receiver_names.join(".")
        end

        def private_delegation?
          private_method?(node)
        end

        def anchor
          declarations.last || private_modifier
        end

        def declarations
          preceding_statements.select { declaration_macro?(it) }
        end

        def preceding_statements
          container_statements.take_while { it != node }
        end

        def private_modifier
          preceding_statements.find { visibility_modifier_of(it) == :private }
        end

        def write(corrector)
          if sibling_delegate
            merge_into_sibling(corrector)
          else
            corrector.insert_after(anchor, "\n#{indentation_of(node)}#{macro_source}")
          end
        end

        # Corrections run in a loop, so this can come past twice: `delegate :about, :about` defines the method twice.
        def merge_into_sibling(corrector)
          return if sibling_delegate.method_names.include?(node.method_name)

          corrector.insert_before(sibling_delegate.first_option, ":#{node.method_name}, ")
        end

        def macro_source
          "delegate :#{node.method_name}, to: #{macro_target}#{private_option}"
        end

        def macro_target
          receiver_names.many? ? "\"#{receiver_path}\"" : ":#{receiver_path}"
        end

        def private_option
          ", private: true" if private_delegation?
        end
    end
end
