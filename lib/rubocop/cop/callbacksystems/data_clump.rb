# Detects when the same group of parameters appears in multiple methods,
# suggesting they should be extracted into a parameter object.
#
# @example
#   # bad - same parameters repeated across methods
#   class Order
#     def create(name, email, phone)
#       validate(name, email, phone)
#       save(name, email, phone)
#     end
#
#     def validate(name, email, phone); end
#     def save(name, email, phone); end
#   end
#
#   # good - extract to parameter object
#   class Order
#     def create(contact)
#       validate(contact)
#       save(contact)
#     end
#
#     def validate(contact); end
#     def save(contact); end
#   end
#
class RuboCop::Cop::Callbacksystems::DataClump < RuboCop::Cop::Base
  MESSAGE = "Parameters `%<params>s` appear together in %<count>d methods. Consider extracting to a parameter object."

  def on_class(node)
    ParameterClumps.new(node, cop_config).detect.each do |param_set, method_nodes|
      message = format(MESSAGE, params: param_set.join(", "), count: method_nodes.size)
      add_offense(method_nodes.first.loc.name, message: message)
    end
  end

  def on_module(node)
    ParameterClumps.new(node, cop_config).detect.each do |param_set, method_nodes|
      message = format(MESSAGE, params: param_set.join(", "), count: method_nodes.size)
      add_offense(method_nodes.first.loc.name, message: message)
    end
  end

  private
    class ParameterClumps
      attr_reader :node, :cop_config

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def detect
        result = Hash.new { |h, k| h[k] = [] }
        methods.combination(2).each { |pair| record_common_params(result, pair) }
        result.select { |_, nodes| nodes.size >= min_methods }
      end

      private
        def methods
          return [] unless node.body

          collect_methods(node.body).filter_map do |child|
            params = param_names_for(child)
            [ child, params ] if params.size >= min_params
          end
        end

        def record_common_params(result, pair)
          common = pair.first.last & pair.last.last
          if common.size >= min_params
            key = common.sort
            result[key] << pair.first.first if result[key].exclude?(pair.first.first)
            result[key] << pair.last.first if result[key].exclude?(pair.last.first)
          end
        end

        def collect_methods(current)
          return [] unless current

          case current.type
          when :begin
            current.children.flat_map { |child| collect_methods(child) }
          when :def
            current.arguments.size >= min_params ? [ current ] : []
          else
            []
          end
        end

        def param_names_for(method_node)
          method_node.arguments.children
            .select { |arg| arg.arg_type? || arg.optarg_type? }
            .map { |arg| arg.children.first.to_s }
        end

        def min_params
          cop_config["MinParams"] || 3
        end

        def min_methods
          cop_config["MinMethods"] || 3
        end
    end
end
