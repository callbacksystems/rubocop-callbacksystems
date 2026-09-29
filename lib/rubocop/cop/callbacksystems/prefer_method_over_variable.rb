# Detects local variable assignments that could be methods instead.
# Assigning to a variable with the same name as the method being called
# suggests the code would be more declarative with a method or delegate.
#
# @example
#   # bad - variable name matches method call (simple receiver)
#   account = user.account
#   plan = @account.plan
#
#   # good - use delegate when method names match
#   delegate :account, to: :user
#   delegate :plan, to: :account
#
#   # good - or extract method
#   def account
#     user.account
#   end
#
#   # bad - finder pattern
#   user = find_user
#   user = User.find(params[:id])
#   order = Order.find_by(number: number)
#
#   # good - extract to method
#   def user
#     User.find(params[:id])
#   end
#
#   # ok - assignment in conditional
#   if user = find_user
#     user.activate
#   end
#
#   # ok - chain receiver (delegate doesn't apply)
#   length = answer.value.to_s.length
#
#   # ok - receiver is a method parameter (delegate doesn't apply)
#   def process(user)
#     account = user.account  # user is a parameter, not a method
#   end
#
#   # ok - different name indicates transformation
#   formatted_date = date.strftime("%Y-%m-%d")
#   active_users = users.select(&:active?)
#
class RuboCop::Cop::Callbacksystems::PreferMethodOverVariable < RuboCop::Cop::Callbacksystems::Base
  def on_lvasgn(node)
    report Assignment.new(node)
  end

  private
    class Assignment
      DELEGATE_MESSAGE = "Variable `%<variable>s` mirrors method call. Use `delegate :%<variable>s, " \
        "to: :%<receiver>s` or extract a method."
      FINDER_MESSAGE = "Variable `%<variable>s` assigned from finder. Consider extracting a `%<variable>s` method."
      CONDITIONAL_TYPES = %i[ if while until while_post until_post case case_match ]

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if message
      end

      private
        attr_reader :node

        def message
          @message ||= delegation_message || finder_message if assigns_a_call? && !inside_conditional?
        end

        def assigns_a_call?
          node.expression&.send_type?
        end

        def inside_conditional?
          node.each_ancestor(*CONDITIONAL_TYPES).any? { condition_holds_assignment?(it.condition) }
        end

        def condition_holds_assignment?(condition)
          condition&.then { it.equal?(node) || it.source_range.contains?(node.source_range) }
        end

        def delegation_message
          format(DELEGATE_MESSAGE, variable: variable_name, receiver: receiver.name) if same_name_with_simple_receiver?
        end

        def same_name_with_simple_receiver?
          value_node.method?(variable_name) && delegatable_receiver?
        end

        def value_node
          node.expression
        end

        def variable_name
          node.name
        end

        # `delegate` needs a method or a reader to send to, which also keeps `now = Time.now` holding its one instant.
        def delegatable_receiver?
          value_node.receiver && !value_node.receiver.lvar_type? && !receiver.chained? && !receiver.name.nil?
        end

        def receiver
          @receiver ||= Receiver.new(value_node)
        end

        def finder_message
          format(FINDER_MESSAGE, variable: variable_name) if finder_call.finds_the_variable?
        end

        def finder_call
          FinderCall.new(variable_name, value_node)
        end
    end

    class Receiver
      include RuboCop::Callbacksystems::Helpers

      def initialize(value_node)
        @value_node = value_node
      end

      def chained?
        value_node.receiver.send_type? && value_node.receiver.receiver
      end

      def name
        case value_node.receiver.type
        when :send then value_node.receiver.method_name
        when :ivar then name_without_sigil(value_node.receiver.name)
        end
      end

      private
        attr_reader :value_node
    end

    class FinderCall
      FINDER_PREFIXES = %w[ find_ get_ fetch_ load_ ]
      CLASS_FINDERS = %w[ find find_by find_by! ]

      def initialize(variable_name, value_node)
        @variable_name = variable_name
        @value_node = value_node
      end

      def finds_the_variable?
        (finder_method? || class_finder?) && !reads_a_local?
      end

      private
        attr_reader :variable_name, :value_node

        def finder_method?
          FINDER_PREFIXES.any? { value_node.method_name.to_s == "#{it}#{variable_name}" }
        end

        def class_finder?
          value_node.receiver&.const_type? &&
            CLASS_FINDERS.include?(value_node.method_name.to_s) &&
            variable_name.to_s == value_node.receiver.short_name.to_s.underscore
        end

        # A method extracted out of here could not read a local of the caller, so a finder given one stays a variable.
        def reads_a_local?
          value_node.each_node(:lvar).any?
        end
    end
end
