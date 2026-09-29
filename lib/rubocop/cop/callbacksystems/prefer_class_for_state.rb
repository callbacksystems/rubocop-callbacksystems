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
# This complements DataClump, which catches *groups* of arguments shared across
# method *signatures*. Here a *single* value threaded around is the smell.
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
  def on_new_investigation
    @method_indexes = MethodIndexes.new(processed_source.ast)
  end

  def on_def(node)
    report_each ThreadedValues.new(node, index: method_indexes.for(node), min_methods: cop_config["MinMethods"])
  end

  alias on_defs on_def

  private
    Call = Data.define(:method_name, :position)
    FlowEdge = Data.define(:method_name, :target)
    ReachResult = Data.define(:method_names, :cyclic)

    attr_reader :method_indexes

    class ThreadedValues
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "`%<name>s` is threaded through %<count>d methods. Make it the state of a class."

      def initialize(node, index:, min_methods:)
        @node = node
        @index = index
        @min_methods = min_methods
      end

      def each_offense
        threaded.each do |name, count|
          yield RuboCop::Callbacksystems::Offense.new \
            definitions.fetch(name),
            format(MESSAGE, name: name, count: count)
        end
      end

      private
        attr_reader :node, :index, :min_methods

        def threaded
          return {} if recursive_origin?

          reach_counts.select { |_, count| count >= min_methods }
        end

        def recursive_origin?
          index.recursive?(node)
        end

        def reach_counts
          definitions.keys.to_h { [ it, reach_size_for(it) ] }
        end

        def definitions
          @definitions ||= parameter_definitions.merge(local_definitions)
        end

        def parameter_definitions
          parameter_nodes_of(node).index_by { it.children.first.to_s }.except(*method_assignments.names)
        end

        def method_assignments
          @method_assignments ||= index.assignments_for(node)
        end

        def local_definitions
          method_assignments.unique_local_definitions.except(*parameter_names)
        end

        def parameter_names
          @parameter_names ||= parameter_nodes_of(node).to_set { it.children.first.to_s }
        end

        def reach_size_for(name)
          index.reach_size(index.flow(name, node))
        end
    end

    # One index per class and method domain keeps receiverless instance calls away from singleton definitions, and lets
    # every origin reuse the same value-flow graph.
    class MethodIndexes
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast)
        @methods_by_container = grouped_methods_in(ast)
      end

      def for(method)
        domain = MethodDomain.new(method)
        if domain.scope
          indexes_for(domain.container)[domain.scope] ||= MethodIndex.new(methods_in(domain))
        else
          MethodIndex.new([])
        end
      end

      private
        attr_reader :methods_by_container

        def grouped_methods_in(ast)
          nodes_in(ast, :class, :module).each_with_object({}.compare_by_identity) do |container, groups|
            groups[container] = direct_method_nodes_in(container.body).group_by { MethodDomain.new(it).scope }
          end
        end

        def indexes_for(container)
          container ? indexes_by_container[container] ||= {} : top_level_indexes
        end

        def indexes_by_container
          @indexes_by_container ||= {}.compare_by_identity
        end

        def top_level_indexes
          @top_level_indexes ||= {}
        end

        def methods_in(domain)
          methods_by_container.fetch(domain.container, {}).fetch(domain.scope, [])
        end
    end

    class MethodDomain
      delegate :container, to: :domain

      def initialize(node)
        @node = node
      end

      def scope
        domain.identity if resolvable?
      end

      private
        attr_reader :node

        def resolvable?
          !node.defs_type? || node.receiver.self_type?
        end

        def domain
          @domain ||= RuboCop::Callbacksystems::Methods::Domain.new(node)
        end
    end

    # Resolves calls within one method domain and memoizes the transitive set reached from every parameter.
    class MethodIndex
      def initialize(methods)
        @methods = methods
      end

      def flow(name, method_node)
        flows_for(method_node)[name] ||= ValueFlow.new(name, method_node, self)
      end

      def parameter_flow(name, position)
        method = methods_by_name[name]
        Parameter.new(method, position, self).flow unless method.nil? || recursive?(method)
      end

      def recursive?(method)
        calls_for(method).body_method_names.include?(method.method_name)
      end

      def assignments_for(method)
        assignments_by_method[method] ||= MethodAssignments.new(method)
      end

      def threading_calls_for(name, method:)
        calls_for(method).named(name)
      end

      def reach_size(flow)
        reachability.result_for(flow).then { it.cyclic ? 0 : it.method_names.size }
      end

      private
        attr_reader :methods

        def flows_for(method)
          flows_by_method[method] ||= {}
        end

        def flows_by_method
          @flows_by_method ||= {}.compare_by_identity
        end

        def methods_by_name
          @methods_by_name ||= methods.index_by(&:method_name)
        end

        def calls_for(method)
          calls_by_method[method] ||= ThreadingCalls.new(method)
        end

        def calls_by_method
          @calls_by_method ||= {}.compare_by_identity
        end

        def assignments_by_method
          @assignments_by_method ||= {}.compare_by_identity
        end

        def reachability
          @reachability ||= Reachability.new(self)
        end
    end

    # One value, a name within a single method body, and the receiverless calls it is passed to.
    class ValueFlow < Data.define(:name, :method_node, :index)
      def threading_calls
        index.threading_calls_for(name, method: method_node)
      end
    end

    # Receiverless calls indexed by every unshadowed local value they carry, with one traversal of the method.
    class ThreadingCalls
      include RuboCop::Callbacksystems::Helpers

      def initialize(method_node)
        @method_node = method_node
      end

      def named(name)
        calls_by_name.fetch(name) { [] }
      end

      def body_method_names
        calls_by_name
        @body_method_names
      end

      private
        attr_reader :method_node

        def calls_by_name
          @calls_by_name ||= {}.tap do |calls|
            @body_method_names = Set.new
            method_node.each_descendant(:send).each { add(it, to: calls) if bare_send?(it) }
          end
        end

        def add(send_node, to:)
          @body_method_names << send_node.method_name if inside_body?(send_node)
          indexed_names = Set.new
          position_known = true

          send_node.arguments.each_with_index do |argument, position|
            name = unshadowed_name_of(argument)
            add_call(send_node, name, position, to:) if new_name?(name, among: indexed_names) && position_known
            position_known &&= !positional_width_ambiguous?(argument)
          end
        end

        def inside_body?(send_node)
          method_node.body&.source_range&.contains?(send_node.source_range)
        end

        def unshadowed_name_of(argument)
          if argument.lvar_type? && !name_rebound_between?(argument.name, node: argument, boundary: method_node)
            argument.name.to_s
          end
        end

        def new_name?(name, among:)
          name && among.add?(name)
        end

        def add_call(send_node, name, position, to:)
          (to[name] ||= []) << Call.new(send_node.method_name, position)
        end

        def positional_width_ambiguous?(argument)
          argument.type?(:splat, :kwsplat, :forwarded_args) || argument.each_descendant(:kwsplat).any?
        end
    end

    class Parameter < Data.define(:method_node, :position, :index)
      include RuboCop::Callbacksystems::Helpers

      def flow
        index.flow(name, method_node) if name && index.assignments_for(method_node).exclude?(name)
      end

      def name
        parameter = method_node.arguments.children[position]
        parameter.children.first.to_s if parameter&.arg_type?
      end
    end

    # Effective local assignments in one method, excluding nested local scopes and explicitly shadowed block locals.
    class MethodAssignments
      include RuboCop::Callbacksystems::Helpers

      delegate :exclude?, to: :names

      def initialize(method_node)
        @method_node = method_node
      end

      def names
        @names ||= assignments.to_set { assignment_name_of(it) }
      end

      def unique_local_definitions
        assignments.group_by { assignment_name_of(it) }.filter_map do |name, definitions|
          [ name, definitions.first ] if definitions.one? && definitions.first.lvasgn_type?
        end.to_h
      end

      private
        attr_reader :method_node

        def assignments
          @assignments ||= AssignmentsWithin.new(method_node.body).reject do |assignment|
            name_rebound_between?(assignment_name_of(assignment), node: assignment, boundary: method_node)
          end
        end

        def assignment_name_of(assignment)
          assignment.children.first.to_s
        end

        class AssignmentsWithin
          include Enumerable
          include RuboCop::Callbacksystems::Helpers

          def initialize(root)
            @root = root
          end

          def each
            if block_given?
              each_assignment { yield it }
            else
              to_enum(__method__)
            end
          end

          private
            attr_reader :root

            def each_assignment
              pending = [ root ].compact
              until pending.empty?
                current = pending.pop
                yield current if current.type?(:lvasgn, :match_var)
                children_of(current).to_a.reverse_each { pending << it }
              end
            end

            def children_of(node)
              lexical_definition?(node) ? immediate_inputs_of(node) : node.each_child_node
            end
        end
    end

    # The cached graph shared by every root within one method domain.
    class Reachability
      attr_reader :results

      def initialize(index)
        @index = index
        @results = {}.compare_by_identity
        @edges = {}.compare_by_identity
      end

      def result_for(flow)
        results[flow] ||= ReachabilityWalk.new(flow, self).result
      end

      def edges_for(flow)
        edges[flow] ||= flow.threading_calls.map do |call|
          FlowEdge.new(call.method_name, index.parameter_flow(call.method_name, call.position))
        end
      end

      private
        attr_reader :index, :edges
    end

    # An iterative walk of the graph rooted at one value flow.
    class ReachabilityWalk
      def initialize(root, reachability)
        @root = root
        @reachability = reachability
        @stack = []
        @visiting = {}.compare_by_identity
      end

      def result
        start(root)
        advance until stack.empty?
        results.fetch(root)
      end

      private
        attr_reader :root, :reachability, :stack, :visiting

        delegate :edges_for, :results, to: :reachability, private: true
        delegate :edge, to: :frame, private: true

        def start(flow)
          visiting[flow] = true
          stack << FlowFrame.new(flow, edges_for(flow))
        end

        def advance
          if frame.complete?
            finish
          elsif edge.target.nil?
            frame.absorb
          else
            advance_to_target
          end
        end

        def frame
          stack.last
        end

        def finish
          results[frame.flow] = frame.result
          visiting.delete(frame.flow)
          stack.pop
        end

        def advance_to_target
          if results.key?(edge.target)
            frame.absorb(results.fetch(edge.target))
          elsif visiting.key?(edge.target)
            frame.absorb(cyclic: true)
          else
            start(edge.target)
          end
        end
    end

    # One explicit stack frame keeps large pipelines off Ruby's call stack.
    class FlowFrame
      attr_reader :flow

      def initialize(flow, edges)
        @flow = flow
        @edges = edges
        @position = 0
        @method_names = Set.new
        @cyclic = false
      end

      def complete?
        position >= edges.size
      end

      def absorb(result = nil, cyclic: false)
        method_names << edge.method_name
        method_names.merge(result.method_names) if result
        remember_cycle(result, explicit: cyclic)
        @position += 1
      end

      def edge
        edges[position]
      end

      def result
        ReachResult.new(method_names:, cyclic:)
      end

      private
        attr_reader :edges, :position, :method_names, :cyclic

        def remember_cycle(result, explicit:)
          @cyclic = cyclic || explicit || result&.cyclic || false
        end
    end
end
