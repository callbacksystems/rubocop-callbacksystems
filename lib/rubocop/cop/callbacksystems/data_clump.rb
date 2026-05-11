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
class RuboCop::Cop::Callbacksystems::DataClump < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Parameters `%<params>s` appear together in %<count>d methods. Consider extracting to a parameter object."

  def on_class(node)
    ParameterClumps.new(node, cop_config).detect.each do |param_set, method_nodes|
      add_offense(method_nodes.first.loc.name, message: format(MESSAGE, params: param_set.join(", "), count: method_nodes.size))
    end
  end

  alias on_module on_class

  private
    class ParameterClumps
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node, :cop_config

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def detect
        result = Hash.new { |hash, key| hash[key] = [] }
        methods_with_params.combination(2).each { record_common_params(result, it) }
        result.select { |_, nodes| nodes.size >= min_methods }
      end

      private
        def methods_with_params
          return [] unless node.body

          method_nodes.filter_map do |method_node|
            params = parameter_names(method_node)
            [ method_node, params ] if params.size >= min_params
          end
        end

        def method_nodes(current = node.body)
          return [] unless current

          case current.type
          when :begin
            current.children.flat_map { method_nodes(it) }
          when :def
            current.arguments.size >= min_params ? [ current ] : []
          else
            []
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

        def min_params
          cop_config["MinParams"]
        end

        def min_methods
          cop_config["MinMethods"]
        end
    end
end
