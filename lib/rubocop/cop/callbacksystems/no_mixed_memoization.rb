# Detects memoization mixed with other statements in the same method.
# A method that memoizes should only do memoization - nothing else.
# Conditional memoization (with if/unless) and rescue blocks are allowed.
#
# @example
#   # bad - memoization with other statements before
#   def user
#     validate_params
#     @user ||= User.find(params[:id])
#   end
#
#   # bad - memoization with other statements after
#   def user
#     @user ||= User.find(params[:id])
#     log_access
#   end
#
#   # good - memoization is the entire method body
#   def user
#     @user ||= User.find(params[:id])
#   end
#
#   # good - conditional memoization
#   def period
#     @period ||= compute_period if params[:starts_on].present?
#   end
#
#   # good - memoization with rescue
#   def processor
#     @processor ||= find_processor
#   rescue ActiveRecord::RecordNotFound
#     nil
#   end
#
#   # good - complex computation inside the memoization
#   def user
#     @user ||= begin
#       data = fetch_data
#       process(data)
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoMixedMemoization < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Memoization should be the entire method body. Extract other statements to separate methods."

  def on_def(node)
    memoization = MemoizationBody.new(node.body)
    add_offense(memoization.memoization_node, message: MESSAGE) if memoization.offense?
  end

  alias on_defs on_def

  private
    class MemoizationBody
      def initialize(body)
        @body = body
      end

      def offense?
        memoization_node && !entire_body_is_memoization?
      end

      def memoization_node
        @memoization_node ||= body&.each_node(:or_asgn)&.find { ivar_memoization?(it) }
      end

      private
        attr_reader :body

        def ivar_memoization?(node)
          node&.or_asgn_type? && node.children.first.ivasgn_type?
        end

        def entire_body_is_memoization?
          simple_memoization? || multiple_memoizations? || conditional_memoization? ||
            memoization_with_rescue? || memoization_then_field_return?
        end

        def simple_memoization?
          ivar_memoization?(body)
        end

        def multiple_memoizations?
          body&.begin_type? && body.children.all? { ivar_memoization?(it) }
        end

        def conditional_memoization?
          body&.if_type? && body.else_branch.nil? && ivar_memoization?(body.if_branch)
        end

        def memoization_with_rescue?
          ivar_memoization?(rescue_node_from_body&.children&.first)
        end

        def rescue_node_from_body
          if body&.rescue_type?
            body
          elsif body&.kwbegin_type? && body.children.first&.rescue_type?
            body.children.first
          end
        end

        # `@user ||= load; @user` (or `; return @user`) reads back the field it just
        # memoized: still a single concern, so it is allowed.
        def memoization_then_field_return?
          body&.begin_type? && body.children.size == 2 &&
            ivar_memoization?(body.children.first) && returns_memoized_ivar?(body.children.last)
        end

        def returns_memoized_ivar?(node)
          read = node.return_type? ? node.children.first : node
          read&.ivar_type? && read.name == memoization_node.lhs.name
        end
    end
end
