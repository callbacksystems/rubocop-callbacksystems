# Ensures methods are ordered by invocation: callers before callees, and a
# caller's callees in the order it first invokes them (depth-first). Public
# methods are ordered before private ones. A macro, block, or lambda that names a
# method (a callback, a delegate target, a validation) calls it too, and it reads
# at the top of the class, so a method reached only that way leads its visibility
# group in the order the macros mention it (a guard before its action, since the
# guard is evaluated first). A method a real method body calls follows that caller
# instead.
#
# The actions of a controller are the exception: `Rails/ActionOrder` owns their
# order, so they lead their group in the order that cop asks for and the walk
# places everything else. A macro naming an action (a `rate_limit :create`) would
# otherwise pull it to the top and the two cops would undo each other forever.
#
# @example
#   # bad - called method defined before caller
#   def helper
#   end
#
#   def process
#     helper
#   end
#
#   # bad - sibling callees defined out of invocation order
#   def process
#     helper_b
#     helper_a
#   end
#
#   def helper_a
#   end
#
#   def helper_b
#   end
#
#   # good - caller before callee, callees in first-invocation order
#   def process
#     helper_a
#     helper_b
#   end
#
#   def helper_a
#   end
#
#   def helper_b
#   end
#
#   # good - with private section
#   def process
#     helper
#   end
#
#   private
#     def helper
#     end
#
#   # good - a callback method leads: its macro calls it and reads at the top
#   after_commit :notify_later
#
#   def notify_later
#     NotifyJob.perform_later(self)
#   end
#
#   def process
#     compute
#   end
#
#   def compute
#   end
#
#   # good - `Rails/ActionOrder` places the actions, whatever a macro names
#   rate_limit :create, to: 10, within: 30.minutes
#
#   def new
#   end
#
#   def create
#   end
#
class RuboCop::Cop::Callbacksystems::MethodInvocationOrder < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    analyze(node, direct_definitions_in(node.body, :def), macro_references: true, actions: actions_of(node))
    analyze(node, direct_definitions_in(node.body, :defs), macro_references: false, actions: [])
  end

  alias on_module on_class

  def on_sclass(node)
    analyze(node, direct_definitions_in(node.body, :def), macro_references: true, actions: [])
  end

  private
    def analyze(node, methods, macro_references:, actions:)
      report_each InvocationOrder.new(processed_source, node, methods, macro_references:, actions:)
    end

    # Read from `Rails/ActionOrder`, since two cops ordering the same methods by different rules undo each other.
    def actions_of(node)
      controller_class?(node) ? expected_action_order : []
    end

    def expected_action_order
      if config.cop_enabled?("Rails/ActionOrder")
        Array(config.for_cop("Rails/ActionOrder")["ExpectedOrder"]).map(&:to_sym)
      else
        []
      end
    end

    class InvocationOrder
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Method `%<expected>s` should be defined before `%<actual>s` to keep callers before callees."

      def initialize(processed_source, node, methods, macro_references:, actions:)
        @processed_source = processed_source
        @node = node
        @methods = methods
        @macro_references = macro_references
        @actions = actions
      end

      def each_offense
        yield offense if analyzable? && divergence.found?
      end

      private
        attr_reader :processed_source, :node, :methods, :macro_references, :actions

        def analyzable?
          node.body && methods.size >= 2 && method_names.uniq.size == method_names.size
        end

        def method_names
          @method_names ||= methods.map(&:method_name)
        end

        def divergence
          @divergence ||= RuboCop::Callbacksystems::ClassStructure::Divergence.new(method_names, from: canonical_order)
        end

        def canonical_order
          @canonical_order ||= LEVELS.flat_map { ordered_by_visibility(it) }
        end

        def ordered_by_visibility(visibility)
          leading_first(full_order.select { visibilities[it] == visibility })
        end

        def leading_first(names)
          leading = leading_order.select { names.include?(it) }

          leading + (names - leading)
        end

        def leading_order
          [ :initialize, *actions ]
        end

        def full_order
          @full_order ||= RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(ordering_seeds, call_graph).to_a
        end

        def ordering_seeds
          macro_led + real_roots + method_names
        end

        def macro_led
          if macro_references
            reference_order.reject { called_methods.include?(it) }
          else
            []
          end
        end

        def reference_order
          @reference_order ||= macro_methods.select { known_method_names.include?(it) }
        end

        def macro_methods
          @macro_methods ||= RuboCop::Callbacksystems::Methods::MacroReferences.new(node.body)
        end

        def known_method_names
          @known_method_names ||= Set.new(method_names)
        end

        def called_methods
          @called_methods ||= Set.new(call_graph.values.flatten)
        end

        def call_graph
          @call_graph ||= methods.to_h { [ it.method_name, calls_from(it) ] }
        end

        def calls_from(method)
          if method.body
            receiverless_method_names_in(method.body).uniq.select { places?(method.method_name, it) }
          else
            []
          end
        end

        # A private caller places no public callee, since the public methods lead whatever reads them from below.
        def places?(caller_name, callee_name)
          known_method_names.include?(callee_name) && level_of(callee_name) >= level_of(caller_name)
        end

        def level_of(name)
          LEVELS.index(visibilities[name])
        end

        def visibilities
          @visibilities ||= methods.to_h { [ it.method_name, visibility_of(it) ] }
        end

        def real_roots
          method_names.reject { called_methods.include?(it) }
        end

        def offense
          RuboCop::Callbacksystems::Offense.new(methods_by_name[divergence.expected], message,
            correcting: method_runs.any?(&:reorderable?)) { reorder(it) }
        end

        def methods_by_name
          @methods_by_name ||= methods.index_by(&:method_name)
        end

        def message
          format(MESSAGE, expected: divergence.expected, actual: divergence.actual)
        end

        def method_runs
          @method_runs ||= runs_in(node.body) { methods.include?(it) }.filter_map { run_of(it) }
        end

        def run_of(members)
          statements = statements_of(members)

          if uninterrupted?(statements)
            RuboCop::Callbacksystems::ClassStructure::StatementRun.new(statements, order: canonical_order) { it.node.method_name }
          end
        end

        def statements_of(members)
          members.map { RuboCop::Callbacksystems::Source::StatementWithComments.new(it, processed_source) }
        end

        # A comment unattached to either method is an intentional boundary, not source for a sortable run.
        def uninterrupted?(statements)
          statements.each_cons(2).none? { |above, below| above.range.end.join(below.range.begin).source.strip.present? }
        end

        def reorder(corrector)
          method_runs.each { it.rewrite(corrector) }
        end
    end
end
