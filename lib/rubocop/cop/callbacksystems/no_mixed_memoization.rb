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
    checker = MemoizationBody.new(node.body)
    memo_node = checker.memoization_node
    add_offense(memo_node, message: MESSAGE) if memo_node && !checker.memoization_is_entire_body?
  end

  private
    class MemoizationBody
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def memoization_node
        body&.each_node(:or_asgn)&.find { ivar_memoization?(it) }
      end

      def memoization_is_entire_body?
        simple_memoization? || multiple_memoizations? || conditional_memoization? || memoization_with_rescue?
      end

      private
        def ivar_memoization?(node)
          node&.or_asgn_type? && node.children.first.ivasgn_type?
        end

        def simple_memoization?
          ivar_memoization?(body)
        end

        def multiple_memoizations?
          body&.begin_type? && body.children.all? { ivar_memoization?(it) }
        end

        def conditional_memoization?
          body&.if_type? && ivar_memoization?(body.children.second)
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
    end
end
