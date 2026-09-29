# Counts only validation guards: leading `return`s that reject input by
# returning nothing, `nil`, or `false`. Dispatch branches like
# `return start_value if start?` are a lookup table written as control flow,
# not validation, so they don't count. Many validations at the start of a
# method usually means the checks belong in an extracted predicate.
#
# @example MaxGuards: 2 (default)
#   # bad - three leading validation guards
#   def process(account)
#     return unless account
#     return false if account.closed?
#     return nil unless account.active?
#     charge(account)
#   end
#
#   # good - extract the validation
#   def process(account)
#     return unless chargeable?(account)
#     charge(account)
#   end
#
class RuboCop::Cop::Callbacksystems::TooManyValidationGuards < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report LeadingGuards.new(node, maximum: cop_config["MaxGuards"])
  end

  alias on_defs on_def

  private
    class LeadingGuards
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method has %<count>d leading validation guards (max %<maximum>d). Extract validation into a helper."

      def initialize(node, maximum:)
        @node = node
        @maximum = maximum
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if count > maximum
      end

      private
        attr_reader :node, :maximum

        def count
          @count ||= leading_zone.count { validation_guard?(it) }
        end

        def leading_zone
          statements_in(node.body).take_while { in_zone?(it) }
        end

        def in_zone?(statement)
          statement.lvasgn_type? || validation_guard?(statement)
        end

        def validation_guard?(statement)
          statement.if_type? && single_branch?(statement) && rejecting_return?(lone_branch_of(statement))
        end

        # A full `if`/`else` is a two-way choice, not a guard.
        def single_branch?(if_node)
          [ if_node.if_branch, if_node.else_branch ].compact.one?
        end

        def rejecting_return?(branch)
          branch.return_type? && (branch.children.empty? || single_rejecting_value?(branch))
        end

        def single_rejecting_value?(return_node)
          return_node.children.one? && return_node.children.first.falsey_literal?
        end

        def lone_branch_of(if_node)
          if_node.if_branch || if_node.else_branch
        end

        def message
          format(MESSAGE, count:, maximum:)
        end
    end
end
