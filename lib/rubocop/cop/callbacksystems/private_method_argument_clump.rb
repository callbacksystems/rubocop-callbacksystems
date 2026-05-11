# Detects when multiple private methods share the same parameters,
# suggesting they should be extracted into a separate object.
#
# When 3+ private methods receive the same 2+ arguments, those arguments
# likely represent a missing object. Extract them to a private nested class,
# or to a separate file if the concept is reusable.
#
# @example
#   # bad - multiple private methods with same parameters
#   class Order
#     def process
#       validate(user, account, permissions)
#       execute(user, account, permissions)
#       notify(user, account, permissions)
#     end
#
#     private
#       def validate(user, account, permissions)
#         # ...
#       end
#
#       def execute(user, account, permissions)
#         # ...
#       end
#
#       def notify(user, account, permissions)
#         # ...
#       end
#   end
#
#   # good - extract to an object
#   class Order
#     def process
#       context = Context.new(user, account, permissions)
#       context.validate
#       context.execute
#       context.notify
#     end
#
#     private
#       class Context
#         def initialize(user, account, permissions)
#           @user = user
#           @account = account
#           @permissions = permissions
#         end
#
#         def validate
#           # ...
#         end
#
#         def execute
#           # ...
#         end
#
#         def notify
#           # ...
#         end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateMethodArgumentClump < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Private methods `%<methods>s` share parameters `%<params>s`. Consider extracting to a private nested class or separate object."

  def on_class(node)
    PrivateMethods.new(node, cop_config).clumps.each do |params, methods|
      add_offense(methods.first, message: format(MESSAGE, methods: methods.map(&:method_name).join(", "), params: params.join(", ")))
    end
  end

  alias on_module on_class
  alias on_sclass on_class

  private
    class PrivateMethods
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node, :cop_config

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def clumps
        grouped_methods.select { |_, methods| methods.size >= min_methods }
      end

      private
        def grouped_methods
          collect_private_methods.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |method, groups|
            params = param_names_for(method)
            groups[params] << method if params.size >= min_params
          end
        end

        def collect_private_methods
          private_methods_in(node).select { it.arguments.size >= min_params }
        end

        def param_names_for(method_node)
          parameter_names(method_node).sort
        end

        def min_params
          cop_config["MinParams"]
        end

        def min_methods
          cop_config["MinMethods"]
        end
    end
end
