# Detects a set of parameter names that travel together across a class's or
# module's private methods, suggesting they belong to an object of their own,
# usually a private nested class holding them as instance state. Only private
# methods are examined, since a public method's signature answers to an
# interface, not internal threading, which is also why the JS rule no-data-clump
# skips exported functions and public members. Methods under `class << self`
# join the group of the class that holds them.
#
# The set is found as a connected component in the co-occurrence graph of shared
# parameter names, meaning names used by two or more methods, linked whenever they
# appear together in one method's signature. Because membership follows the
# graph, not an exact repeated tuple, this catches names sharing *varying*
# combinations, as in `m1(a, b)`, `m2(a, c)`, `m3(b, c)`, where no single pair
# repeats. Only methods carrying two or more of the names count toward a set,
# since one name is a value arriving, not a concept being passed, and counting
# such bystanders would let a lone name clear the set threshold instead of its
# own higher one.
# A one-letter name is left out, since it is a placeholder `NoSingleLetterNames` already flags.
#
# How far a set has to spread depends on how much its shape already tells. A
# signature repeated verbatim counts from `MinMethodsForRepeatedSignature`
# methods, two by default, because nothing in those parameter lists explains the
# co-occurrence except the concept itself. Names that come with extras of their
# own might merely have met, so those need `MinMethods`, three by default, and a
# lone name threaded through the class has to reach `MinMethodsForSingleParam`,
# six by default. The recursion subject is exempt, since a name passed both as
# itself and as a derivative of itself in the same call (`walk(node.child, node)`)
# changes at every step and cannot become shared state.
#
# @example
#   # bad - a signature repeated verbatim is telling from two methods already
#   class Order
#     private
#       def validate(user, account); end
#       def execute(user, account); end
#   end
#
#   # bad - a shared core with extras of its own, once it reaches three methods
#   class Order
#     private
#       def create(name, email, phone); end
#       def validate(name, email, address); end
#       def save(name, phone, address); end
#   end
#
#   # bad - one value threaded through six methods
#   class Visitor
#     private
#       def first(node); end
#       def second(node); end
#       def third(node); end
#       def fourth(node); end
#       def fifth(node); end
#       def sixth(node); end
#   end
#
#   # good - a private nested class holds the values as state
#   class Order
#     def process
#       context = Context.new(user, account)
#       context.validate
#       context.execute
#     end
#
#     private
#       class Context
#         def initialize(user, account)
#           @user = user
#           @account = account
#         end
#
#         def validate; end
#         def execute; end
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::DataClump < RuboCop::Cop::Callbacksystems::Base
  def on_class(node)
    report_each ParameterClumps.new(node, limits)
  end

  alias on_module on_class

  private
    def limits
      Limits.new \
        min_methods: cop_config["MinMethods"],
        min_methods_for_repeated_signature: cop_config["MinMethodsForRepeatedSignature"],
        min_methods_for_single_parameter: cop_config["MinMethodsForSingleParam"]
    end

    class ParameterClumps
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, limits)
        @node = node
        @limits = limits
      end

      def each_offense
        clumps.each { yield RuboCop::Callbacksystems::Offense.new(it.location, it.message) }
      end

      private
        attr_reader :node, :limits

        def clumps
          SignatureGroup.new(signatures, limits).clumps
        end

        def signatures
          internal_methods.map { Signature.new(it, exempt_names) }.select { it.names.any? }
        end

        def internal_methods
          @internal_methods ||= direct_method_nodes_in(node.body).select { internal_method?(it) }
        end

        def internal_method?(method_node)
          private_nested_class?(node) || private_method?(method_node)
        end

        def exempt_names
          @exempt_names ||= internal_methods.flat_map { recursion_subject_names_of(it) }.to_set
        end

        def recursion_subject_names_of(method_node)
          RuboCop::Callbacksystems::Execution::Immediate.new(method_node.body).nodes_of_type(:send, :csend)
            .flat_map { recursion_subjects_in(it) }
        end
    end

    # Reads a method group's shared names as connected components, each its own hidden object.
    class SignatureGroup
      MIN_SHARING_METHODS = 2

      def initialize(signatures, limits)
        @signatures = signatures
        @limits = limits
      end

      def clumps
        candidates.select { limits.reached_by?(it) }
      end

      private
        attr_reader :signatures, :limits

        def candidates
          graph.map { clump_for(it) }
        end

        def graph
          Graph.new(shared_names, signatures)
        end

        def shared_names
          name_counts.select { |_, count| count >= MIN_SHARING_METHODS }.keys
        end

        def name_counts
          signatures.flat_map(&:names).tally
        end

        def clump_for(names)
          Clump.new(signatures.select { it.counts_toward?(names) }, names)
        end
    end

    # The shared names linked by the signatures they appear in together, read as its connected components.
    class Graph
      include Enumerable

      delegate :each, to: :components

      def initialize(shared_names, signatures)
        @shared_names = shared_names
        @signatures = signatures
      end

      private
        attr_reader :shared_names, :signatures

        def components
          each_component.to_a
        end

        def each_component
          if block_given?
            remaining = shared_names.to_set
            until remaining.empty?
              component = component_of(remaining.first)
              yield component
              remaining.subtract(component)
            end
          else
            enum_for(__method__)
          end
        end

        def component_of(name)
          closure_of(Set[name])
        end

        def closure_of(names)
          names.dup.tap do |reached|
            pending = names.to_a
            position = 0
            visited_signatures = {}.compare_by_identity

            until position == pending.size
              signatures_by_name.fetch(pending[position]).each do |signature|
                next if visited_signatures.key?(signature)

                visited_signatures[signature] = true
                signature.names.each do |neighbor|
                  pending << neighbor if shared_name?(neighbor) && reached.add?(neighbor)
                end
              end
              position += 1
            end
          end
        end

        def signatures_by_name
          @signatures_by_name ||= shared_names.index_with { [] }.tap do |index|
            signatures.each do |signature|
              signature.names.each { index.fetch(it) << signature if index.key?(it) }
            end
          end
        end

        def shared_name?(name)
          shared_name_index.include?(name)
        end

        def shared_name_index
          @shared_name_index ||= shared_names.to_set
        end
    end

    class Clump < Data.define(:signatures, :names)
      MESSAGE = "Parameters `%<parameters>s` travel together through %<count>d private methods (`%<methods>s`). " \
        "Consider a private nested class holding them as instance state."
      SINGLE_PARAMETER_MESSAGE = "Parameter `%<parameter>s` is threaded through %<count>d private methods " \
        "(`%<methods>s`). Consider a private nested class holding it as instance state."

      def message
        lone_name? ? threaded_parameter_message : shared_parameters_message
      end

      def lone_name?
        names.one?
      end

      # Stronger than a shared core, since the methods take the set and nothing besides.
      def repeated_signature?
        signatures.map(&:sorted_names).uniq.one?
      end

      def location
        signatures.first.node.loc.name
      end

      def count
        signatures.size
      end

      private
        def threaded_parameter_message
          format(SINGLE_PARAMETER_MESSAGE, parameter: sorted_parameter_names.first, count:, methods: method_names)
        end

        def sorted_parameter_names
          names.sort
        end

        def method_names
          signatures.map(&:method_name).join(", ")
        end

        def shared_parameters_message
          format(MESSAGE, parameters: sorted_parameter_names.join(", "), count:, methods: method_names)
        end
    end

    class Signature
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node, :names

      delegate :method_name, to: :node

      def initialize(node, exempt_names)
        @node = node
        @names = parameter_names_of(node).uniq.reject { exempt_names.include?(it) || it.length == 1 }
      end

      # A method carrying one name of a set is a bystander, so a set needs two of its names to appear in a signature.
      def counts_toward?(wanted)
        shared_count_in(wanted) >= (wanted.many? ? 2 : 1)
      end

      def shared_count_in(wanted)
        names.count { wanted.include?(it) }
      end

      # A one-letter name is a placeholder rather than a concept, and `NoSingleLetterNames` already asks for a word.
      def sorted_names
        @sorted_names ||= names.sort
      end
    end

    # The thresholds mirror the JS rule no-data-clump, so the two configs agree on what qualifies.
    class Limits
      def initialize(min_methods:, min_methods_for_repeated_signature:, min_methods_for_single_parameter:)
        @min_methods = min_methods
        @min_methods_for_repeated_signature = min_methods_for_repeated_signature
        @min_methods_for_single_parameter = min_methods_for_single_parameter
      end

      def reached_by?(clump)
        clump.count >= reach_for(clump)
      end

      private
        attr_reader :min_methods, :min_methods_for_repeated_signature, :min_methods_for_single_parameter

        def reach_for(clump)
          if clump.lone_name?
            min_methods_for_single_parameter
          elsif clump.repeated_signature?
            min_methods_for_repeated_signature
          else
            min_methods
          end
        end
    end
end
