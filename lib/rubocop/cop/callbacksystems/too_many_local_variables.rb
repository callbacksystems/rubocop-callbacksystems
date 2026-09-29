# Flags methods with too many local variable assignments.
# Too many local variables often indicates imperative code that could
# be made more declarative by extracting methods.
#
# @example MaxAssignments: 3 (default)
#   # bad - imperative with local variables
#   def process
#     user = find_user
#     account = user.account
#     plan = account.plan
#     features = plan.features
#     # ...
#   end
#
#   # good - declarative with methods
#   def process
#     apply_features
#   end
#
#   def features
#     plan.features
#   end
#
#   def plan
#     account.plan
#   end
#
#   def account
#     user.account
#   end
#
#   def user
#     User.find(user_id)
#   end
#
#   # good - attribute assignments don't count
#   def configure
#     config.timeout = 30
#     config.retries = 3
#     config.verbose = true
#   end
#
class RuboCop::Cop::Callbacksystems::TooManyLocalVariables < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report LocalVariableAssignments.new(node, max: cop_config["MaxAssignments"])
  end

  alias on_defs on_def

  private
    class LocalVariableAssignments
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method has %<count>d local variable assignments (max %<max>d). " \
        "Extract methods instead of using local variables."

      def initialize(node, max:)
        @node = node
        @max = max
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if count > max
      end

      private
        attr_reader :node, :max

        def count
          @count ||= assignment_count(node.body, :lvasgn, :match_var)
        end

        def message
          format(MESSAGE, count:, max:)
        end
    end
end
