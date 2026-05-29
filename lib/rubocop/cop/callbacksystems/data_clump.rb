# Detects a set of parameter names that travel together across a class's or
# module's private methods, suggesting they should be extracted into a parameter
# object. Only private methods are examined: a public method's signature answers
# to an interface, not internal threading: the same reason the JS rule skips
# exported functions and public members.
#
# The set is found as a connected component in the co-occurrence graph of shared
# parameter names: names used by two or more methods, linked whenever they appear
# together in one method's signature. A component that reaches enough methods is
# the object those methods should hold as state instead of passing the values
# around. Because membership follows the graph, not an exact repeated tuple, this
# catches names sharing *varying* combinations: `m1(a, b)`, `m2(a, c)`,
# `m3(b, c)`, where no single pair repeats. A lone name that spreads far enough
# counts on its own. The recursion subject is exempt: a name passed both as
# itself and as a derivative of itself in the same call (`walk(node.child, node)`)
# changes at every step and cannot become shared state.
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
#   # bad - the same names travel together in varying combinations
#   class Order
#     def create(name, email, phone); end
#     def validate(name, email, address); end
#     def save(name, phone, address); end
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
    ParameterClumps.new(node, cop_config).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class

  private
    class ParameterClumps
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def each_offense(&block)
        if block
          clump = ClumpSearch.new(signatures, limits).clump
          yield clump.location, format(MESSAGE, params: clump.params.join(", "), count: clump.count) if clump
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node, :cop_config

        def signatures
          internal_methods.map { Signature.new(it, exempt_names) }.select { it.names.any? }
        end

        # Public methods answer to an interface and are not ours to reshape, so
        # only private methods clump. A private nested class is itself internal,
        # so all of its methods count.
        def internal_methods
          direct_method_nodes_in(node.body).select { internal_method?(it) }
        end

        def internal_method?(method_node)
          private_nested_class?(node) || private_method?(method_node)
        end

        def exempt_names
          @exempt_names ||= recursion_subject_names_in(node)
        end

        def limits
          {
            min_methods: cop_config["MinMethods"],
            min_methods_for_single_param: cop_config["MinMethodsForSingleParam"]
          }
        end
    end

    # One method's eligible parameter names: its significant names, deduplicated,
    # minus the exempt ones.
    Signature = Data.define(:node, :exempt_names) do
      include RuboCop::Callbacksystems::Helpers

      def reaches?(wanted)
        names.any? { wanted.include?(it) }
      end

      def names
        parameter_names_of(node).uniq.reject { exempt_names.include?(it) }
      end
    end

    # Searches a method group for the connected component of shared names that
    # reaches the most methods, returning the single strongest clump.
    class ClumpSearch
      MIN_SHARING_METHODS = 2

      def initialize(signatures, limits)
        @signatures = signatures
        @limits = limits
      end

      def clump
        qualifying_clumps.max_by { [ it.count, it.params.size ] }
      end

      private
        attr_reader :signatures, :limits

        def qualifying_clumps
          components.filter_map { clump_for(it) }.select { it.qualifies?(limits) }
        end

        def components
          Graph.new(shared_names, signatures).components
        end

        def shared_names
          name_counts.select { |_, count| count >= MIN_SHARING_METHODS }.keys
        end

        def name_counts
          signatures.flat_map(&:names).tally
        end

        def clump_for(names)
          Clump.new(signatures.select { it.reaches?(names) }, names)
        end
    end

    Clump = Data.define(:signatures, :names) do
      # Two tiers, mirroring the JS rule no-data-clump: a multi-name clump needs
      # min_methods reaches; a lone name needs the higher single-param threshold.
      def qualifies?(limits)
        count >= (names.many? ? limits[:min_methods] : limits[:min_methods_for_single_param])
      end

      def location
        signatures.first.node.loc.name
      end

      def count
        signatures.size
      end

      def params
        names.sort
      end
    end

    # The co-occurrence graph of shared names.
    class Graph
      def initialize(shared_names, signatures)
        @adjacency = shared_names.to_h { [ it, Set.new ] }
        signatures.each { link(it.names) }
      end

      def components
        seen = Set.new
        adjacency.keys.filter_map { component_from(it, seen) unless seen.include?(it) }
      end

      private
        attr_reader :adjacency

        def link(names)
          shared = names.select { adjacency.key?(it) }
          shared.each { connect_within(it, shared) }
        end

        def connect_within(name, others)
          others.each { adjacency[name] << it unless name == it }
        end

        def component_from(name, seen)
          return [] if seen.include?(name)

          seen << name
          [ name, *adjacency[name].flat_map { component_from(it, seen) } ]
        end
    end
end
