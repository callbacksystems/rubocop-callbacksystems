# Detects a single value threaded through many method calls: a parameter or a
# local passed as an argument to several different receiverless methods, directly
# or down a pipeline. Such a value is instance state in disguise: it reads
# better as the state of a class, with the methods that receive it becoming
# instance methods that no longer need the argument.
#
# The value is followed by *data flow*: every receiverless method it is passed to
# as an argument, then (through that callee's matching parameter) wherever it
# flows next, transitively across the class. So a value handed from `rewrite` to
# `process` to `decorate` counts all three, even though no single method passes it
# four times. The flow is not followed through a *recursive* method: there the
# value is a moving cursor over a structure, not one value held as state.
#
# This complements DataClump and PrivateMethodArgumentClump, which catch *groups*
# of arguments shared across method *signatures*. Here a *single* value threaded
# around is the smell.
#
# @example
#   # bad - `node` is passed to every helper
#   def rewrite(node)
#     validate(node)
#     decorate(node)
#     persist(node)
#     index(node)
#   end
#
#   # bad - `node` is threaded down a pipeline
#   def rewrite(node)
#     process(node)
#   end
#
#   def process(value)
#     decorate(value)
#     persist(value)
#     index(value)
#   end
#
#   # good - `node` becomes the state of a class; the helpers become its methods
#   def rewrite(node)
#     Rewrite.new(node).perform
#   end
#
#   class Rewrite
#     def initialize(node)
#       @node = node
#     end
#
#     def perform
#       validate
#       decorate
#       persist
#       index
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferClassForState < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "`%<name>s` is threaded through %<count>d methods. Make it the state of a class."

  def on_def(node)
    ThreadedValues.new(node, cop_config).each_offense do |offense_node, message|
      add_offense(offense_node, message: message)
    end
  end

  alias on_defs on_def

  private
    class ThreadedValues
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def each_offense(&block)
        if block
          threaded.each { |name, count| yield definitions.fetch(name), format(MESSAGE, name: name, count: count) }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node, :cop_config

        # A self-recursive method walks a structure: its values are moving cursors
        # over that structure, not one value held as state, so none are reported.
        def threaded
          return {} if recursive_origin?

          reach_counts.select { |_, count| count >= min_methods }
        end

        def recursive_origin?
          receiverless_method_names_in(node.body).include?(node.method_name)
        end

        def reach_counts
          definitions.keys.to_h { [ it, reach_size_for(it) ] }
        end

        def definitions
          @definitions ||= parameter_definitions.merge(local_definitions)
        end

        def parameter_definitions
          node.arguments.children
            .select { parameter_node?(it) }
            .index_by { it.children.first.to_s }
        end

        def local_definitions
          method_level_assignments.index_by { it.name.to_s }
        end

        def method_level_assignments
          node.each_descendant(:lvasgn).select { scope_of(it) == node }
        end

        def scope_of(descendant)
          descendant.each_ancestor(:any_def, :any_block).first
        end

        def reach_size_for(name)
          reach = Reach.new(index)
          reach.cyclic?(ValueFlow.new(name, node, index), Set[node.method_name]) ? 0 : reach.count
        end

        def index
          @index ||= MethodIndex.new(container)
        end

        def container
          node.each_ancestor(:class, :module, :sclass).first
        end

        def min_methods
          cop_config["MinMethods"]
        end
    end

    # Walks the data-flow graph from a value, collecting the distinct methods it
    # reaches and detecting whether the flow loops back onto a method already on the
    # path. A value that cycles through mutually recursive helpers is a cursor over a
    # structure, not state, so it is exempt.
    Reach = Struct.new(:index) do
      def initialize(index)
        super
        @callees = Set.new
      end

      def count
        @callees.size
      end

      def cyclic?(flow, path)
        flow.threading_calls.any? { loops_back?(it, path) }
      end

      def loops_back?(call, path)
        return true if path.include?(call.method_name)

        !@callees.include?(call.method_name) && descends?(call, path)
      end

      def descends?(call, path)
        @callees << call.method_name
        next_flow = index.parameter_flow(call.method_name, call.position)
        next_flow ? cyclic?(next_flow, path + [ call.method_name ]) : false
      end
    end

    # Resolves a receiverless call's method name and argument position to the
    # value flow it lands on in the callee, so a value can be followed across a
    # method boundary.
    MethodIndex = Struct.new(:container) do
      include RuboCop::Callbacksystems::Helpers

      def parameter_flow(name, position)
        method = methods_by_name[name]
        Parameter.new(method, position, self).flow unless method.nil? || recursive?(method)
      end

      def methods_by_name
        @methods_by_name ||= methods.index_by(&:method_name)
      end

      def methods
        container ? direct_method_nodes_in(container.body) : []
      end

      def recursive?(method)
        receiverless_method_names_in(method.body).include?(method.method_name)
      end
    end

    # A method parameter resolved by position, exposing the value flow it carries:
    # the parameter name scoped to its method body.
    Parameter = Data.define(:method_node, :position, :index) do
      include RuboCop::Callbacksystems::Helpers

      def flow
        ValueFlow.new(name, method_node, index) if name
      end

      def name
        parameter = method_node.arguments.children[position]
        parameter.children.first.to_s if parameter_node?(parameter)
      end
    end

    # One value (a name within a single method body) and the receiverless
    # calls it is passed to. The unit followed by the transitive search.
    ValueFlow = Data.define(:name, :method_node, :index) do
      include RuboCop::Callbacksystems::Helpers

      def threading_calls
        method_node.each_descendant(:send).select { bare_send?(it) }.filter_map { call_in(it) }
      end

      def call_in(send_node)
        position = send_node.arguments.find_index { passes_value?(it) }
        Call.new(send_node.method_name, position) if position
      end

      def passes_value?(argument)
        argument.lvar_type? && argument.children.first.to_s == name && !shadowed?(argument)
      end

      # A block between the reference and the method that binds an argument of the
      # same name introduces a different value: the reference is no longer the
      # parameter being followed. Numbered and `it` blocks bind `_1`/`it`, which
      # never collide with a named parameter, so they cannot shadow.
      def shadowed?(argument)
        blocks_above(argument).any? { rebinds_name?(it) }
      end

      def blocks_above(argument)
        argument.each_ancestor(:block).take_while { it != method_node }
      end

      def rebinds_name?(block)
        block.argument_list.any? { it.respond_to?(:name) && it.name.to_s == name }
      end
    end

    Call = Data.define(:method_name, :position)
end
