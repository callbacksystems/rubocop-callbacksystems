# Detects when multiple private methods share parameters, suggesting they
# should be extracted into a separate object.
#
# When 3+ private methods receive the same 2+ arguments, those arguments
# likely represent a missing object. Extract them to a private nested class,
# or to a separate file if the concept is reusable.
#
# A single parameter threaded through many private methods is the same smell
# spread across the class: that one value is really the state those helpers
# operate on, so it is flagged once it reaches a higher method count. Public
# methods form the class API, so they never count toward either shape. The
# recursion subject is exempt: a value passed both as itself and as a
# derivative of itself in the same call (`walk(node.child, node)`) changes at
# every step and cannot become instance state.
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
  SINGLE_PARAMETER_MESSAGE = "Parameter `%<param>s` is threaded through private methods `%<methods>s`. Consider a private nested class holding it as instance state."

  def on_class(node)
    PrivateMethods.new(node, cop_config).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class
  alias on_sclass on_class

  private
    class PrivateMethods
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def each_offense(&block)
        if block
          group_clumps.each { |params, methods| yield methods.first, group_message(params, methods) }
          single_parameter_clumps.each { |param, methods| yield methods.first, single_parameter_message(param, methods) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node, :cop_config

        def group_clumps
          grouped_by_parameter_set.select { |_, methods| methods.size >= min_methods }
        end

        def grouped_by_parameter_set
          methods_with_parameters
            .group_by { sorted_parameter_names_of(it) }
            .select { |params, _| params.size >= min_params }
        end

        def methods_with_parameters
          private_methods_in(node).select { it.arguments.size >= min_params }
        end

        def min_params
          cop_config["MinParams"]
        end

        def sorted_parameter_names_of(method_node)
          parameter_names_of(method_node).sort
        end

        def min_methods
          cop_config["MinMethods"]
        end

        def group_message(params, methods)
          format(MESSAGE, methods: method_names_of(methods), params: params.join(", "))
        end

        def method_names_of(methods)
          methods.map(&:method_name).join(", ")
        end

        def single_parameter_clumps
          methods_by_parameter.select { |_, methods| methods.size >= min_methods_for_single_param }
        end

        def methods_by_parameter
          shared_parameter_pairs.group_by(&:first).transform_values { it.map(&:last) }
        end

        def shared_parameter_pairs
          parameter_method_pairs.reject { recursion_subjects.include?(it.first) }
        end

        def parameter_method_pairs
          private_methods_in(node).flat_map { parameters_paired_with(it) }
        end

        def parameters_paired_with(method_node)
          parameter_names_of(method_node).uniq.map { [ it, method_node ] }
        end

        def recursion_subjects
          @recursion_subjects ||= recursion_subject_names_in(node)
        end

        def min_methods_for_single_param
          cop_config["MinMethodsForSingleParam"]
        end

        def single_parameter_message(param, methods)
          format(SINGLE_PARAMETER_MESSAGE, param: param, methods: method_names_of(methods))
        end
    end
end
