# Detects `@x = receiver.x` style assignments inside `initialize` that mirror
# a method call. These eager assignments are better expressed as `delegate`
# declarations: they read declaratively, avoid duplicating the name, and stop
# inviting bigger refactors (the very anti-pattern flagged by
# `NoRedundantWrapperMethod` and `NoAnemicDelegation`).
#
# Only assignments where the ivar name matches the called method name are
# flagged, and only when the receiver itself is also assigned to an ivar of
# the same name in the same `initialize` (so the receiver is reachable via
# `attr_reader` from the surrounding class).
#
# @example
#   # bad - eager assignment that mirrors `node.body`
#   def initialize(node)
#     @node = node
#     @body = node.body
#   end
#
#   private
#     attr_reader :node, :body
#
#   # good - declare the delegation
#   def initialize(node)
#     @node = node
#   end
#
#   private
#     attr_reader :node
#     delegate :body, to: :node, private: true
#
#   # ok - the assignment transforms the value (different name from the call)
#   def initialize(name)
#     @name = name
#     @name_parts = name.split("_")
#   end
#
class RuboCop::Cop::Callbacksystems::PreferDelegateOverIvarAssignment < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Replace `@%<name>s = %<receiver>s.%<name>s` with `delegate :%<name>s, to: :%<receiver>s`."

  def on_ivasgn(node)
    assignment = Assignment.new(node)
    add_offense(node, message: assignment.offense_message) if assignment.mirroring_delegation?
  end

  private
    class Assignment
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Helpers

      # @!method mirroring_assignment?(node)
      def_node_matcher :mirroring_assignment?, <<~PATTERN
        (ivasgn $_ (send (lvar $_) $_))
      PATTERN

      # @!method receiver_assignment?(node, ivar_name, lvar_name)
      def_node_matcher :receiver_assignment?, <<~PATTERN
        (ivasgn %1 (lvar %2))
      PATTERN

      def initialize(node)
        @node = node
      end

      def mirroring_delegation?
        target_name && ivar_matches_method? && inside_initialize?(node) && receiver_assigned_to_ivar?
      end

      def offense_message
        format(MESSAGE, name: method_name, receiver: receiver_name)
      end

      private
        attr_reader :node

        def target_name
          parts&.first
        end

        def parts
          @parts ||= mirroring_assignment?(node)
        end

        def ivar_matches_method?
          target_name.to_s.delete_prefix("@").to_sym == method_name
        end

        def method_name
          parts&.fetch(2)
        end

        def receiver_assigned_to_ivar?
          ivar = :"@#{receiver_name}"
          sibling_assignments.any? { receiver_assignment?(it, ivar, receiver_name) }
        end

        def receiver_name
          parts&.fetch(1)
        end

        def sibling_assignments
          statements_in(node.each_ancestor(:any_def).first.body)
        end
    end
end
