# Detects memoization mixed with other statements in the same method. A
# memoized method reads as a value, so a statement beside the `||=` runs on the
# first read and never again, an effect hidden behind a getter that the caller
# has no way to see. Conditional memoization (with if/unless) and rescue
# blocks are allowed.
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
  def on_def(node)
    report MemoizationBody.new(node)
  end

  alias on_defs on_def

  private
    class MemoizationBody
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Memoization should be the entire method body. Extract other statements to separate methods."

      def initialize(method_node)
        @method_node = method_node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(memoization_node, MESSAGE) if mixed?
      end

      private
        attr_reader :method_node
        delegate :body, to: :method_node, private: true

        def mixed?
          memoization_node && !entire_body_is_memoization?
        end

        def memoization_node
          @memoization_node ||= RuboCop::Callbacksystems::Execution::Immediate.new(body).nodes_of_type(:or_asgn)
            .find { instance_variable_memoization?(it) }
        end

        def instance_variable_memoization?(node)
          node&.or_asgn_type? && node.children.first.ivasgn_type?
        end

        def entire_body_is_memoization?
          simple_memoization? || multiple_memoizations? || conditional_memoization? ||
            memoization_with_rescue? || memoization_then_field_return?
        end

        def simple_memoization?
          instance_variable_memoization?(effective_body)
        end

        def effective_body
          @effective_body ||= TransparentExpression.new(body).value
        end

        def multiple_memoizations?
          effective_body.type?(:begin, :kwbegin) &&
            effective_body.children.all? { instance_variable_memoization?(it) }
        end

        def conditional_memoization?
          effective_body.if_type? && effective_body.else_branch.nil? &&
            instance_variable_memoization?(effective_body.if_branch)
        end

        def memoization_with_rescue?
          instance_variable_memoization?(rescue_node&.children&.first)
        end

        def rescue_node
          effective_body if effective_body.rescue_type?
        end

        # `@user ||= load; @user` reads back the field it just memoized, which is still a single concern.
        def memoization_then_field_return?
          effective_body.type?(:begin, :kwbegin) && effective_body.children.size == 2 &&
            instance_variable_memoization?(effective_body.children.first) &&
            returns_memoized_variable?(effective_body.children.last)
        end

        def returns_memoized_variable?(node)
          reads_variable?(returned_expression_of(node), memoization_node.lhs.name)
        end

        class TransparentExpression
          def initialize(node)
            @node = node
          end

          def value
            node.then do |current|
              current = current.children.first while transparent?(current)
              current
            end
          end

          private
            attr_reader :node

            def transparent?(current)
              current.type?(:begin, :kwbegin) && current.children.one?
            end
        end
    end
end
