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
class RuboCop::Cop::Callbacksystems::PreferMethodOverVariable < RuboCop::Cop::Base
  DELEGATE_MESSAGE = "Variable `%<var>s` mirrors method call. Use `delegate :%<var>s, to: :%<receiver>s` or extract a method."
  FINDER_MESSAGE = "Variable `%<var>s` assigned from finder. Consider extracting a `%<var>s` method."

  def on_lvasgn(node)
    Assignment.new(node, self).check
  end

  private
    class Assignment
      attr_reader :node, :cop

      def initialize(node, cop)
        @node = node
        @cop = cop
      end

      def check
        return if skip_assignment?

        variable_name = node.children.first
        value_node = node.children.second
        Value.new(node, variable_name, value_node, cop).check
      end

      private
        def skip_assignment?
          !node.children.second&.send_type? || inside_conditional?
        end

        def inside_conditional?
          node.parent&.type == :if && node.parent.condition == node
        end
    end

    class Value
      attr_reader :node, :variable_name, :value_node, :cop

      def initialize(node, variable_name, value_node, cop)
        @node = node
        @variable_name = variable_name
        @value_node = value_node
        @cop = cop
      end

      def check
        if same_name_with_simple_receiver?
          receiver_name = Receiver.new(value_node).name_for
          cop.send(:add_offense, node, message: format(DELEGATE_MESSAGE, var: variable_name, receiver: receiver_name))
        elsif FinderPattern.new(variable_name, value_node).matches?
          cop.send(:add_offense, node, message: format(FINDER_MESSAGE, var: variable_name))
        end
      end

      private
        def same_name_with_simple_receiver?
          value_node.method_name == variable_name && delegatable_receiver?
        end

        def delegatable_receiver?
          value_node.receiver && !Receiver.new(value_node).chain_receiver? && !parameter_receiver?
        end

        def parameter_receiver?
          value_node.receiver.lvar_type? && parameter?(value_node.receiver.children.first)
        end

        def parameter?(receiver_variable_name)
          node.each_ancestor(:def, :defs, :block).any? do |ancestor|
            ancestor.arguments.any? { |arg| arg.name == receiver_variable_name }
          end
        end
    end

    class Receiver
      attr_reader :value_node

      def initialize(value_node)
        @value_node = value_node
      end

      def chain_receiver?
        value_node.receiver.send_type? && value_node.receiver.receiver
      end

      def name_for
        case value_node.receiver.type
        when :send
          value_node.receiver.method_name
        when :lvar
          value_node.receiver.children.first
        when :ivar
          value_node.receiver.children.first.to_s.delete_prefix("@")
        else
          "receiver"
        end
      end
    end

    class FinderPattern
      attr_reader :variable_name, :value_node

      def initialize(variable_name, value_node)
        @variable_name = variable_name
        @value_node = value_node
      end

      def matches?
        matches_finder_method? || matches_class_finder?
      end

      private
        def matches_finder_method?
          %w[find_ get_ fetch_ load_].any? do |prefix|
            value_node.method_name.to_s == "#{prefix}#{variable_name}"
          end
        end

        def matches_class_finder?
          value_node.receiver&.const_type? &&
            %w[find find_by find_by!].include?(value_node.method_name.to_s) &&
            variable_name.to_s == value_node.receiver.children.last.to_s.underscore
        end
    end
end
