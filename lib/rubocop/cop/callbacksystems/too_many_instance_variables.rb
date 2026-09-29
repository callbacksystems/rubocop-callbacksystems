# Flags private methods with too many instance variable assignments.
# Too many instance variable assignments often indicates a method is doing too much.
# The `initialize` method and public methods are excluded.
# Public methods (like controller actions) often need multiple instance variables.
#
# @example MaxAssignments: 2 (default)
#   # bad - too many instance variable assignments in private method
#   private
#     def setup_request
#       @user = find_user
#       @account = find_account
#       @permissions = load_permissions
#     end
#
#   # good - single responsibility
#   private
#     def set_user
#       @user = find_user
#     end
#
#   # good - public methods can have many (e.g., controller actions)
#   def show
#     @user = find_user
#     @account = find_account
#     @permissions = load_permissions
#   end
#
#   # good - initialize can have many
#   def initialize(user, account)
#     @user = user
#     @account = account
#     @created_at = Time.current
#   end
#
class RuboCop::Cop::Callbacksystems::TooManyInstanceVariables < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report InstanceVariableAssignments.new(node, max: cop_config["MaxAssignments"])
  end

  alias on_defs on_def

  private
    class InstanceVariableAssignments
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method has %<count>d instance variable assignments (max %<max>d). " \
        "Consider splitting into separate methods."

      def initialize(node, max:)
        @node = node
        @max = max
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if private_non_initializer? && count > max
      end

      private
        attr_reader :node, :max

        def private_non_initializer?
          direct_method_definition?(node) && !node.method?(:initialize) && !public_method?(node)
        end

        def count
          @count ||= instance_assignments.to_set(&:name).size
        end

        def instance_assignments
          RuboCop::Callbacksystems::Execution::Immediate.new(node.body).nodes_of_type(:ivasgn)
            .select { self_preserved_between?(it, boundary: node) }
        end

        def message
          format(MESSAGE, count:, max:)
        end
    end
end
