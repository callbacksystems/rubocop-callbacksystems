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
class RuboCop::Cop::Callbacksystems::PrivateMethodArgumentClump < RuboCop::Cop::Base
  CONTAINER_TYPES = %i[begin kwbegin].freeze

  # Matches: private (with no arguments)
  def_node_matcher :private_declaration?, <<~PATTERN
    (send nil? :private)
  PATTERN

  def on_class(node)
    PrivateMethods.new(node, cop_config, self).check
  end

  def on_module(node)
    PrivateMethods.new(node, cop_config, self).check
  end

  def on_sclass(node)
    PrivateMethods.new(node, cop_config, self).check
  end

  private
    class PrivateMethods
      attr_reader :node, :cop_config, :cop

      def initialize(node, cop_config, cop)
        @node = node
        @cop_config = cop_config
        @cop = cop
      end

      def check
        grouped_methods.each do |params, methods|
          next if methods.size < min_methods

          message = "Private methods `#{methods.map(&:method_name).join(", ")}` share parameters `#{params.join(", ")}`. Consider extracting to a private nested class or separate object."
          cop.send(:add_offense, methods.first, message: message)
        end
      end

      private
        def grouped_methods
          collect_private_methods.each_with_object(Hash.new { |h, k| h[k] = [] }) do |method, groups|
            params = param_names_for(method)
            groups[params] << method if params.size >= min_params
          end
        end

        def collect_private_methods
          return [] unless node.body

          { in_private: false, methods: [] }.then do |state|
            traverse(node.body) do |child|
              state[:in_private] = true if cop.send(:private_declaration?, child)
              next unless state[:in_private] && child.def_type?

              state[:methods] << child if child.arguments.size >= min_params
            end
            state[:methods]
          end
        end

        def traverse(body, &block)
          return unless body

          yield body
          body.children.each { |child| traverse(child, &block) } if CONTAINER_TYPES.include?(body.type)
        end

        def param_names_for(method_node)
          method_node.arguments.children
            .select { |arg| arg.arg_type? || arg.optarg_type? }
            .map { |arg| arg.children.first.to_s }
            .sort
        end

        def min_params
          cop_config["MinParams"] || 2
        end

        def min_methods
          cop_config["MinMethods"] || 3
        end
    end
end
