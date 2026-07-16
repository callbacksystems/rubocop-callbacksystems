# Ensures methods are ordered by invocation: callers before callees, and a
# caller's callees in the order it first invokes them (depth-first). Public
# methods are ordered before private ones. A macro, block, or lambda that names a
# method (a callback, a delegate target, a validation) calls it too, and it reads
# at the top of the class, so a method reached only that way leads its visibility
# group in the order the macros mention it (a guard before its action, since the
# guard is evaluated first). A method a real method body calls follows that caller
# instead.
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
class RuboCop::Cop::Callbacksystems::MethodInvocationOrder < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Method `%<expected>s` should be defined before `%<actual>s` to keep callers before callees."

  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    analyze(node, direct_methods_in(node, :def), macro_references: true)
    analyze(node, direct_methods_in(node, :defs), macro_references: false)
  end

  alias on_module on_class

  def on_sclass(node)
    analyze(node, direct_methods_in(node, :def), macro_references: true)
  end

  private
    def analyze(node, methods, macro_references:)
      graph = CallGraph.new(node, methods, macro_references:)
      order = graph.canonical_order
      graph.each_offense do |offense_node, message|
        add_offense(offense_node, message: message) { Reorder.new(processed_source, node, methods, order, it).rewrite }
      end
    end

    def direct_methods_in(node, type)
      statements_in(node.body).select { it.type == type }
    end

    # Rewrites each contiguous run of method definitions into canonical order,
    # carrying leading comments with their method. A non-method statement between
    # methods (a `private`, a macro) keeps the runs on either side separate.
    class Reorder
      include RuboCop::Cop::RangeHelp
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source, node, methods, order, corrector)
        @processed_source = processed_source
        @node = node
        @methods = methods
        @order = order
        @corrector = corrector
      end

      def rewrite
        method_runs.each { reorder_run(it) }
      end

      private
        attr_reader :processed_source, :node, :methods, :order, :corrector

        def method_runs
          method_statements
            .slice_when { |left, right| methods.exclude?(left) || methods.exclude?(right) }
            .select { methods.include?(it.first) }
        end

        def method_statements
          statements_in(node.body)
        end

        def reorder_run(run)
          ordered = ordered_run(run)
          corrector.replace(run_range(run), join_blocks(ordered)) unless ordered == run
        end

        def ordered_run(run)
          if run.all? { order.include?(it.method_name) }
            run.sort_by { order.index(it.method_name) }
          else
            run
          end
        end

        def run_range(run)
          range_between(block_start_of(run.first), run.last.source_range.end_pos)
        end

        def block_start_of(member)
          range = (leading_comments_of(member).first || member).source_range
          range.begin_pos - range.column
        end

        def leading_comments_of(member)
          contiguous_comments_above(member.first_line - 1, [])
        end

        def contiguous_comments_above(line, collected)
          comment = own_line_comment_at(line)
          comment ? contiguous_comments_above(line - 1, [ comment, *collected ]) : collected
        end

        def own_line_comment_at(line)
          processed_source.comments.find { it.loc.line == line && own_line_comment?(it) }
        end

        def join_blocks(members)
          members.map { block_source_of(it) }.join("\n\n")
        end

        def block_source_of(member)
          range_between(block_start_of(member), member.source_range.end_pos).source
        end
    end

    class CallGraph
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, methods, macro_references:)
        @node = node
        @methods = methods
        @macro_references = macro_references
      end

      def each_offense(&block)
        if block
          report_divergence(&block) if analyzable?
        else
          to_enum(__method__)
        end
      end

      def canonical_order
        @canonical_order ||= ordered_by_visibility(:public) + ordered_by_visibility(:private)
      end

      private
        attr_reader :node, :methods, :macro_references

        def analyzable?
          node.body && methods.size >= 2
        end

        def report_divergence
          index = divergence_index
          yield offense_node(index), offense_message(index) if index
        end

        # The first position where the methods as written diverge from the order
        # callers-before-callees would put them in.
        def divergence_index
          method_names.each_index.find { method_names[it] != canonical_order[it] }
        end

        def method_names
          @method_names ||= methods.map(&:method_name)
        end

        def ordered_by_visibility(visibility)
          full_order.select { visibilities[it] == visibility }
        end

        # One depth-first pass in reading priority: a method referenced by a macro
        # is called by that macro, which reads at the top, so those methods lead
        # their group in the order the macros mention them (a guard before its
        # action). Then the plain entry points and everything they reach, then any
        # cycle. Visibility groups are partitioned afterwards. A method a real
        # method body calls is placed by that call, not hoisted here.
        def full_order
          @full_order ||= begin
            ordering_seeds.each { visit(it) }
            collected
          end
        end

        def ordering_seeds
          macro_led + real_roots + method_names
        end

        # Macro-referenced methods that no method body calls: the macro is their
        # caller and it reads at the top, so they lead, in reference order.
        def macro_led
          if macro_references
            reference_order.reject { called_methods.include?(it) }
          else
            []
          end
        end

        def reference_order
          @reference_order ||= macro_methods.ordered.select { known_method_names.include?(it) }
        end

        def macro_methods
          @macro_methods ||= RuboCop::Callbacksystems::MacroReferencedMethods.new(node.body)
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
            receiverless_method_names_in(method.body).uniq.select { known_method_names.include?(it) }
          else
            []
          end
        end

        def real_roots
          method_names.reject { called_methods.include?(it) }
        end

        def visit(name)
          return if visited.include?(name) || !known_method_names.include?(name)

          visited << name
          collected << name
          call_graph.fetch(name, []).each { visit(it) }
        end

        def visited
          @visited ||= Set.new
        end

        def collected
          @collected ||= []
        end

        def visibilities
          @visibilities ||= methods.to_h { [ it.method_name, visibility_of(it) ] }
        end

        def offense_node(index)
          methods_by_name[canonical_order[index]]
        end

        def methods_by_name
          @methods_by_name ||= methods.index_by(&:method_name)
        end

        def offense_message(index)
          format(MESSAGE, expected: canonical_order[index], actual: method_names[index])
        end
    end
end
