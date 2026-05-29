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
  MESSAGE = "Method has %<count>d instance variable assignments (max %<max>d). " \
    "Consider splitting into separate methods."

  def on_def(node)
    return if node.method?(:initialize) || public_method?(node)

    count = assignment_count(node.body, :ivasgn)
    add_offense(node, message: format(MESSAGE, count: count, max: max_assignments)) if count > max_assignments
  end

  alias on_defs on_def

  private
    def max_assignments
      cop_config["MaxAssignments"]
    end
end
