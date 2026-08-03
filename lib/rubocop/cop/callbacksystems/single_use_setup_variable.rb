# Detects instance variables assigned in setup blocks that are used in at most one test. Such variables should be
# inlined into the test where they are used (or removed if unused).
#
# @example
#   # bad - @order is only used in one test
#   setup do
#     @order = orders(:one)
#   end
#
#   test "order is valid" do
#     assert @order.valid?
#   end
#
#   test "something else" do
#     assert true
#   end
#
#   # bad - @order is not used in any test
#   setup do
#     @order = orders(:one)
#   end
#
#   # good - variable used in multiple tests
#   setup do
#     @order = orders(:one)
#   end
#
#   test "order is valid" do
#     assert @order.valid?
#   end
#
#   test "order has items" do
#     assert @order.items.any?
#   end
#
class RuboCop::Cop::Callbacksystems::SingleUseSetupVariable < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::TestCopHelpers
  extend RuboCop::Cop::AutoCorrector

  USED_ONCE_MESSAGE = "Instance variable `%<variable>s` is only used in one test. Inline it instead of assigning in `setup`."
  UNUSED_MESSAGE = "Instance variable `%<variable>s` assigned in `setup` is not used by any test. Remove it."

  def on_new_investigation
    each_offense do |assignment, message, inline_target, removal_range|
      rewrite = Rewrite.new(assignment, inline_target, removal_range)
      add_offense(assignment, message: message) { rewrite.apply(it) }
    end
  end

  private
    def each_offense(&block)
      if block
        setup_blocks.each { yield_block_offenses(it, &block) } if investigable?
      else
        to_enum(__method__)
      end
    end

    def investigable?
      processed_source.ast && !abstract_test_class?
    end

    def abstract_test_class?
      top_level_class = processed_source.ast.each_node(:class).first
      top_level_class && abstract_base_class?(top_level_class)
    end

    def abstract_base_class?(class_node)
      rails_test_base_class?(class_node.parent_class) && test_blocks(class_node).empty?
    end

    def yield_block_offenses(setup, &block)
      SetupBlock.new(setup, processed_source, test_blocks).each_offense(&block)
    end

    class SetupBlock
      include RuboCop::Callbacksystems::Helpers

      def initialize(setup, processed_source, tests)
        @setup = setup
        @processed_source = processed_source
        @tests = tests
      end

      def each_offense
        offenses.each { yield it[:node], it[:message], *correction_for(it) }
      end

      private
        attr_reader :setup, :processed_source, :tests
        delegate :ast, :comments, to: :processed_source, private: true

        def offenses
          @offenses ||= assignments.filter_map { offense_for(it) }
        end

        def assignments
          setup.body ? setup.body.each_node(:ivasgn).to_a : []
        end

        def offense_for(assignment)
          SetupAssignment.new(assignment, ast, tests).offense
        end

        # The inlining goes with the removal: doing one without the other would leave the value in two places.
        def correction_for(offense)
          range = removal_range_for(offense)
          spared?(range) ? [ offense[:inline_target], range ] : [ nil, nil ]
        end

        def removal_range_for(offense)
          range_for_removable(offense[:node]) if offense[:removable]
        end

        def range_for_removable(node)
          if cleared?
            node.equal?(first_removable) ? block_range : nil
          else
            line_removal_range_for(node)
          end
        end

        # A note in the block has nowhere else to go, so the block stays behind to hold it and the assignments come out
        # a line at a time.
        def cleared?
          nothing_left? && !holds_comment?(block_range, comments)
        end

        def nothing_left?
          removable_nodes.size == statements_in(setup.body).size
        end

        def removable_nodes
          offenses.filter_map { it[:node] if it[:removable] }
        end

        def block_range
          range = setup.source_range
          range.with(begin_pos: range.begin_pos - range.column, end_pos: after_trailing_blank(range))
        end

        def after_trailing_blank(range)
          source = range.source_buffer.source
          skip_newline(source, skip_newline(source, range.end_pos))
        end

        def skip_newline(source, position)
          source[position] == "\n" ? position + 1 : position
        end

        def first_removable
          removable_nodes.min_by { it.source_range.begin_pos }
        end

        def spared?(range)
          range.nil? || !holds_comment?(range, comments)
        end
    end

    class SetupAssignment
      include RuboCop::Callbacksystems::Helpers

      OFFENDING_KINDS = %i[unused single_use].freeze
      INLINABLE_TYPES = %i[int float rational complex str dstr sym dsym regexp true false nil self array hash const lvar ivar cvar gvar].freeze

      def initialize(node, ast, tests)
        @node = node
        @ast = ast
        @tests = tests
      end

      def offense
        { node: node, message: message, inline_target: inline_target, removable: removable? } if offending?
      end

      private
        attr_reader :node, :ast, :tests

        def offending?
          OFFENDING_KINDS.include?(kind)
        end

        def kind
          @kind ||= IvarUsage.new(ast, node.name, tests).classify
        end

        def message
          format(unused? ? UNUSED_MESSAGE : USED_ONCE_MESSAGE, variable: node.name)
        end

        def unused?
          kind == :unused
        end

        def inline_target
          sole_reference if inlinable_single_use?
        end

        def inlinable_single_use?
          single_use? && inlinable?
        end

        def single_use?
          kind == :single_use
        end

        def inlinable?
          inlinable_value? && sole_reference_outside_blocks?
        end

        def inlinable_value?
          INLINABLE_TYPES.include?(value.type) || primary_call?
        end

        def value
          node.expression
        end

        def primary_call?
          value.call_type? && plain_method? && primary_shape?
        end

        def plain_method?
          !value.operator_method? && !value.comparison_method?
        end

        def primary_shape?
          value.receiver || bare_arguments_absent?
        end

        def bare_arguments_absent?
          value.arguments.empty? || value.parenthesized?
        end

        def sole_reference_outside_blocks?
          sole_reference && inner_blocks.none? { it.source_range.contains?(sole_reference.source_range) }
        end

        def sole_reference
          references.first if references.one?
        end

        def references
          using_test ? variable_references_in(using_test) : []
        end

        def using_test
          @using_test ||= tests.find { variable_references_in(it).any? }
        end

        def variable_references_in(scope)
          scope.each_node(:ivar).select { it.name == node.name }
        end

        def inner_blocks
          using_test.each_node(:any_block).reject { it.equal?(using_test) }
        end

        def removable?
          direct_statement? && deletable?
        end

        def direct_statement?
          statements_in(setup_block.body).any? { it.equal?(node) }
        end

        def setup_block
          node.each_ancestor(:block).find { it.method?(:setup) }
        end

        def deletable?
          discardable? || !inline_target.nil?
        end

        # An unread assignment still runs what built it: deleting `@record = Record.create!` takes the record the tests
        # rely on.
        def discardable?
          unused? && inert_value?
        end

        def inert_value?
          INLINABLE_TYPES.include?(value.type) || fixture_read?
        end

        def fixture_read?
          RuboCop::Callbacksystems::FixtureCall.new(value).valid?
        end
    end

    class IvarUsage
      def initialize(ast, variable_name, test_blocks)
        @ast = ast
        @variable_name = variable_name
        @test_blocks = test_blocks
      end

      def classify
        return :ok if used_outside_tests?

        case tests_using_variable
        when 0 then :unused
        when 1 then :single_use
        else :ok
        end
      end

      private
        attr_reader :ast, :variable_name, :test_blocks

        def used_outside_tests?
          variable_references.any? { !inside_test_block?(it) }
        end

        def variable_references
          ast.each_node(:ivar).select { it.name == variable_name }
        end

        def inside_test_block?(ivar_node)
          test_blocks.any? { it.source_range.contains?(ivar_node.source_range) }
        end

        def tests_using_variable
          test_blocks.count do |test_block|
            test_block.each_node(:ivar).any? { it.name == variable_name }
          end
        end
    end

    # How one offending assignment rewrites away. A heredoc value travels in two pieces: its marker moves, its body
    # follows.
    class Rewrite
      def initialize(assignment, inline_target, removal_range)
        @assignment = assignment
        @inline_target = inline_target
        @removal_range = removal_range
      end

      def apply(corrector)
        inline(corrector)
        discard(corrector)
      end

      private
        attr_reader :assignment, :inline_target, :removal_range

        def inline(corrector)
          if inline_target
            corrector.replace(inline_target, value.source)
            bodies.relocate_under(corrector, inline_target)
          end
        end

        def value
          assignment.expression
        end

        def bodies
          @bodies ||= RuboCop::Callbacksystems::HeredocBodies.new(value)
        end

        def discard(corrector)
          if removal_range
            corrector.remove(removal_range)
            bodies.remove(corrector, covered_by: removal_range)
          end
        end
    end
end
