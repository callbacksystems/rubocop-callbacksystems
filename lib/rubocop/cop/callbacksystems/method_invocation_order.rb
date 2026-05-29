# Ensures methods are ordered by invocation: callers before callees, and a
# caller's callees in the order it first invokes them (depth-first). Public
# methods are ordered before private ones. Methods referenced by macros
# (callbacks, delegates, etc.) are pinned and may be defined anywhere.
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
#   # good - method referenced by callback can be defined anywhere
#   included do
#     after_commit :notify_later
#   end
#
#   def notify_later
#     NotifyJob.perform_later(self)
#   end
#
class RuboCop::Cop::Callbacksystems::MethodInvocationOrder < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Method `%<expected>s` should be defined before `%<actual>s` to keep callers before callees."

  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    graph = CallGraph.new(node)
    order = graph.canonical_order
    graph.each_offense do |offense_node, message|
      add_offense(offense_node, message: message) { Reorder.new(processed_source, node, order, it).rewrite }
    end
  end

  alias on_module on_class

  private
    # Rewrites each contiguous run of method definitions into canonical order,
    # carrying leading comments with their method. Macro-pinned methods (absent
    # from the canonical order) are left in place.
    class Reorder
      include RuboCop::Cop::RangeHelp
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source, node, order, corrector)
        @processed_source = processed_source
        @node = node
        @order = order
        @corrector = corrector
      end

      def rewrite
        method_runs.each { reorder_run(it) }
      end

      private
        attr_reader :processed_source, :node, :order, :corrector

        def method_runs
          method_statements
            .slice_when { |left, right| !(left.def_type? && right.def_type?) }
            .select { it.first.def_type? }
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

        def own_line_comment?(comment)
          processed_source.lines[comment.loc.line - 1].slice(0, comment.loc.column).strip.empty?
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

      def initialize(node)
        @node = node
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
        attr_reader :node

        def analyzable?
          node.body && methods.size >= 2
        end

        def methods
          @methods ||= direct_method_nodes_in(node.body)
        end

        def report_divergence
          index = divergence_index
          yield offense_node(index), offense_message(index) if index
        end

        # The first position where the methods as written diverge from the order
        # callers-before-callees would put them in.
        def divergence_index
          actual_order.each_index.find { actual_order[it] != canonical_order[it] }
        end

        def actual_order
          @actual_order ||= method_names.reject { macro_referenced.include?(it) }
        end

        def method_names
          @method_names ||= methods.map(&:method_name)
        end

        def macro_referenced
          @macro_referenced ||= RuboCop::Callbacksystems::MacroReferencedMethods.new(node.body).all
        end

        def ordered_by_visibility(visibility)
          dfs_order.select { visibilities[it] == visibility }
        end

        # One depth-first pass collects every non-macro method in invocation
        # order; the two visibility groups are partitioned from it afterwards, so
        # visibility no longer travels through the traversal.
        def dfs_order
          @dfs_order ||= begin
            seeds.each { visit(it) }
            collected
          end
        end

        # DFS seeds in reading priority: roots (called by nobody) first, then every
        # method in source order as a fallback for cycles. Macro-pinned methods are
        # never seeds: they may sit anywhere, so they must not drive the order.
        def seeds
          @seeds ||= root_names + method_names
        end

        def root_names
          method_names.reject { called_methods.include?(it) }
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

        def known_method_names
          @known_method_names ||= Set.new(method_names)
        end

        def visit(name)
          return if visited.include?(name) || !known_method_names.include?(name)

          visited << name
          collected << name unless macro_referenced.include?(name)
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
          format(MESSAGE, expected: canonical_order[index], actual: actual_order[index])
        end
    end
end
