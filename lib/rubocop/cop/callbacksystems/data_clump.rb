# Detects a set of parameter names that travel together across a class's or
# module's private methods. Those values are one concept, and the methods passing
# them around should be its methods instead. Only private methods are examined: a
# public method's signature answers to an interface, not internal threading: the
# same reason the JS rule skips exported functions and public members.
#
# The set is found as a connected component in the co-occurrence graph of shared
# parameter names: names used by two or more methods, linked whenever they appear
# together in one method's signature. A component that reaches enough methods is
# the object those methods should hold as state instead of passing the values
# around. Because membership follows the graph, not an exact repeated tuple, this
# catches names sharing *varying* combinations: `m1(a, b)`, `m2(a, c)`,
# `m3(b, c)`, where no single pair repeats. A lone name that spreads far enough
# counts on its own.
#
# Only methods carrying two or more of the names count toward a set: one name is
# a value arriving, not a concept being passed, and counting those bystanders
# would let a lone name clear the set threshold instead of its own higher one.
# What a recursion moves is exempt too, since it is a different value at every
# step: see the Recursion helper for the two shapes that say so.
#
# How far a set has to reach depends on how much its shape already tells us. A
# signature repeated verbatim counts from two methods: nothing in those
# parameter lists explains the co-occurrence except the concept itself. Names
# that come with extras of their own might merely have met, so those need a
# third method, and a lone name has to spread further still.
#
# Components partition the shared names, so a class holding two of them is
# hiding two objects and gets one offense for each.
#
# This sees parameter lists only. The same concept bagged into a hash and reached
# into is the identical smell in another spelling, and belongs to NoAnemicRecord.
#
# @example
#   # bad - same parameters repeated across methods
#   class Order
#     def create(name, email, phone)
#       validate(name, email, phone)
#       save(name, email, phone)
#     end
#
#     private
#       def validate(name, email, phone); end
#       def save(name, email, phone); end
#   end
#
#   # bad - the same names travel together in varying combinations
#   class Order
#     private
#       def create(name, email, phone); end
#       def validate(name, email, address); end
#       def save(name, phone, address); end
#   end
#
#   # good - extract to a class the methods belong to
#   class Order
#     def create(contact)
#       Contact.new(contact).save
#     end
#
#     private
#       class Contact
#         def initialize(name, email, phone)
#           @name, @email, @phone = name, email, phone
#         end
#
#         def save
#           validate
#         end
#
#         private
#           def validate; end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::DataClump < RuboCop::Cop::Callbacksystems::Base
  TIGHT_MESSAGE = "Methods `%<methods>s` all take `%<params>s`. Those values are one concept: give it a class and let these become its methods."
  WOVEN_MESSAGE = "Methods `%<methods>s` thread `%<params>s` between them. Those values are one concept: give it a class and let these become its methods."

  def on_class(node)
    ParameterClumps.new(node, cop_config).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_module on_class
  alias on_sclass on_class

  private
    class ParameterClumps
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def each_offense(&block)
        if block
          ClumpSearch.new(signatures, limits).clumps.each { yield it.location, it.message }
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
          Limits.new \
            repeated_signature: cop_config["MinMethodsForRepeatedSignature"],
            shared_names: cop_config["MinMethods"],
            single_param: cop_config["MinMethodsForSingleParam"]
        end
    end

    # The reach a clump needs before it counts. A signature repeated verbatim is
    # already telling at two methods: nothing in those parameter lists explains
    # the co-occurrence except the concept itself. Once the methods carry extras
    # of their own the names might merely have met, so a third method is what
    # makes the pattern a pattern, and a lone name has to spread further still.
    class Limits < Data.define(:repeated_signature, :shared_names, :single_param)
      def reached_by?(clump)
        clump.count >= reach_for(clump)
      end

      private
        def reach_for(clump)
          if clump.names.many?
            clump.repeated_signature? ? repeated_signature : shared_names
          else
            single_param
          end
        end
    end

    # One method's eligible parameter names: its significant names, deduplicated,
    # minus the exempt ones.
    class Signature < Data.define(:node, :exempt_names)
      include RuboCop::Callbacksystems::Helpers

      # A method carrying one name of the component is a value arriving, not a
      # concept being passed around. Counting those bystanders would let a lone
      # name clear the multi-name threshold instead of the higher one the
      # single-name shape has of its own, and would make the message claim a
      # togetherness nothing checked.
      def reaches?(wanted)
        shared_count_in(wanted) >= (wanted.many? ? 2 : 1)
      end

      def shared_count_in(wanted)
        names.count { wanted.include?(it) }
      end

      def names
        parameter_names_of(node).uniq.reject { exempt_names.include?(it) }
      end
    end

    # Searches a method group for the connected components of shared names and
    # keeps every one that reaches far enough.
    class ClumpSearch
      MIN_SHARING_METHODS = 2

      def initialize(signatures, limits)
        @signatures = signatures
        @limits = limits
      end

      def clumps
        qualifying_clumps.sort_by { it.location.line }
      end

      private
        attr_reader :signatures, :limits

        def qualifying_clumps
          components.map { clump_for(it) }.select { limits.reached_by?(it) }
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

    class Clump < Data.define(:signatures, :names)
      def message
        format(tight? ? TIGHT_MESSAGE : WOVEN_MESSAGE, methods: method_names.join(", "), params: params.join(", "))
      end

      # Stronger than tight: the methods take the set and nothing besides.
      def repeated_signature?
        signatures.map { it.names.sort }.uniq.one?
      end

      def count
        signatures.size
      end

      def location
        signatures.first.node.loc.name
      end

      private
        # Tight when every method takes the whole set, one object handed around;
        # otherwise the names are woven through overlapping subsets. Same concept
        # and same refactor, but the report should not claim the first when what
        # it found was the second.
        def tight?
          signatures.all? { it.shared_count_in(names) == names.size }
        end

        def method_names
          signatures.map { it.node.method_name }
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
