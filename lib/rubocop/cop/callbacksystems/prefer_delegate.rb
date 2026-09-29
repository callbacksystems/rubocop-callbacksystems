# Detects methods that only delegate to a same-named method on a delegatable
# receiver (`def size; node.size; end`). The `delegate` macro says it
# declaratively, whether the receiver is a constant, a call on self or a chain
# of them.
#
# Rails/Delegate covers the public single-hop case, so what is left here is the
# private one (the macro defines public methods unless told otherwise), the
# nested one, where a chain of calls becomes a dotted target that Rails/Delegate
# does not recognize, and the one that forwards a block, which it does not read
# because it matches positional arguments only. The macro forwards the block on
# its own.
#
# A private method taking no parameters reads its arguments from its own state,
# so delegating it changes arity and every call site has to start passing them,
# which is why the offense is only reported. The same public method is left
# alone, since its callers are not all in view and a command line is one of
# them. So is a method that combines its own parameters with data of its own,
# a partial application that every call site would have to repeat.
#
# The autocorrection folds the method into an existing same-target `delegate`
# when one is present, keeping them on one line, and otherwise writes a fresh
# macro where the section already declares things, below its mixins when it
# declares nothing yet.
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
#   # bad - the method exists only to hand the block over
#   def each(&block)
#     blocks.each(&block)
#   end
#
#   # good
#   delegate :each, to: :blocks
#
#   # bad - callers must pass the argument: subunit_factor(options[:currency])
#   private
#     def subunit_factor
#       Currency.subunit_factor(options[:currency])
#     end
#
#   # good - delegating would make every call site repeat the slot names
#   def parse(raw)
#     WALPressure.parse(raw, slot_names: SLOTS)
#   end
#
class RuboCop::Cop::Callbacksystems::PreferDelegate < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
  end

  def on_def(node)
    report ManualDelegation.new(node, @source_comments)
  end

  private
    class ManualDelegation
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Use `%<macro>s` instead of a hand-written delegation%<arguments_note>s."

      def initialize(node, source_comments)
        @node = node
        @source_comments = source_comments
      end

      def offense
        if declarable?
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: correctable?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_comments
        delegate :body, to: :node, private: true

        def declarable?
          declarable_delegation? && (forwards_own_parameters? ? beyond_rails_delegate? : binds_own_state?)
        end

        # `delegate` declares public and private methods, so a protected one has no macro to stand in its place.
        def declarable_delegation?
          body&.send_type? && body.method?(node.method_name) && target.delegable? &&
            !protected_method?(node) && declared_in_class_body?
        end

        def target
          @target ||= RuboCop::Callbacksystems::Methods::DelegationTarget.new(body.receiver)
        end

        # A macro stands where the definition stands, so one nested in a conditional or a block has no place to give it.
        def declared_in_class_body?
          statements_in(enclosing_definition_of(node)&.body).any? { it.equal?(statement) }
        end

        def statement
          @statement ||= visibility_applied_to(node.parent, node) ? node.parent : node
        end

        def forwards_own_parameters?
          body.arguments.map(&:source) == node.arguments.map(&:source)
        end

        def beyond_rails_delegate?
          private_method?(node) || target.nested? || forwards_block?
        end

        def forwards_block?
          node.arguments.any?(&:blockarg_type?)
        end

        def binds_own_state?
          node.arguments.empty? && private_method?(node)
        end

        def message
          format MESSAGE,
            macro: conversion.macro_source,
            arguments_note: forwards_own_parameters? ? "" : " and pass the arguments at the call sites"
        end

        def conversion
          @conversion ||= Conversion.new(node, target, source_comments)
        end

        def correctable?
          forwards_own_parameters? && conversion.placeable?
        end

        def correct(corrector)
          conversion.apply(corrector)
        end
    end

    class Conversion
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, target, source_comments)
        @node = node
        @target = target
        @source_comments = source_comments
      end

      def placeable?
        (sibling_delegate.present? || anchor.present?) && !comments_attached_to_definition?
      end

      def apply(corrector)
        write(corrector)
        corrector.remove(statement_removal_range_for(node))
      end

      def macro_source
        "delegate :#{node.method_name}, to: #{target.source}#{private_option}"
      end

      private
        attr_reader :node, :target, :source_comments

        def sibling_delegate
          @sibling_delegate ||= container_macros.find { sibling?(it) }
        end

        def container_macros
          container_statements.map { RuboCop::Callbacksystems::Methods::DelegateMacro.new(it) }
        end

        def container_statements
          statements_in(enclosing_definition_of(node).body)
        end

        def sibling?(macro)
          macro.macro? && macro.target == target.name && macro.plain?(private: private_delegation?)
        end

        def private_delegation?
          private_method?(node)
        end

        def anchor
          @anchor ||= declarations.last || private_modifier || mixins.last
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

        def mixins
          preceding_statements.select { mixin_macro?(it) }
        end

        def comments_attached_to_definition?
          source_comments.any_on_lines?(node.first_line..node.last_line) ||
            source_comments.own_line_comment_on(node.first_line - 1).present?
        end

        def write(corrector)
          if sibling_delegate
            corrector.insert_before(sibling_delegate.first_option, ":#{node.method_name}, ")
          else
            corrector.insert_after(anchor, "#{separator}#{indentation_of(node)}#{macro_source}")
          end
        end

        # After a mixin the macro keeps the blank line that belongs there, and elsewhere it joins the line above.
        def separator
          mixins.any? { it.equal?(anchor) } ? "\n\n" : "\n"
        end

        def private_option
          ", private: true" if private_delegation?
        end
    end
end
