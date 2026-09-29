# Detects an instance variable assigned in `setup` that at most one test reads.
# A `setup` assignment says the tests share the value, so a reader keeps it in
# mind for every test, where one read by a single test belongs in that test,
# and one no test reads is a record the file loads for nothing.
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
  include RuboCop::Callbacksystems::Testing::CopHelpers
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    test_domains.each { report_each it } if processed_source.ast
  end

  private
    def test_domains
      TestDomains.new(processed_source.ast, processed_source:, setups: setup_blocks, tests: test_blocks)
    end

    class TestContext
      attr_reader :tests, :writes, :setup_callbacks, :processed_source

      def initialize(tests:, reads:, writes:, setup_callbacks:, processed_source:)
        @tests = tests
        @writes = writes
        @setup_callbacks = setup_callbacks
        @processed_source = processed_source
        @variable_usages = InstanceVariableUsages.new(reads, tests:)
      end

      def usage_of(variable_name)
        variable_usages.for(variable_name)
      end

      private
        attr_reader :variable_usages
    end

    # Each class or concern owns its setup, tests, and reads; names repeated in another container are unrelated.
    class TestDomains
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast, processed_source:, setups:, tests:)
        @ast = ast
        @processed_source = processed_source
        @setups = setups
        @tests = tests
      end

      def each
        setup_groups.each do |scope, grouped_setups|
          context = TestContext.new(tests: test_groups.fetch(scope, []), reads: read_groups.fetch(scope, []),
            writes: write_groups.fetch(scope, []), setup_callbacks: setup_callback_groups.fetch(scope, []),
            processed_source:)

          yield TestDomain.new(scope, setups: grouped_setups, context:)
        end
      end

      private
        attr_reader :ast, :processed_source, :setups, :tests

        def setup_groups
          @setup_groups ||= groups_of(setups)
        end

        def groups_of(nodes)
          {}.compare_by_identity.tap do |groups|
            nodes.each { (groups[scope_of(it)] ||= []) << it }
          end
        end

        def scope_of(node)
          RuboCop::Callbacksystems::Methods::Domain.new(node).container || ast
        end

        def test_groups
          @test_groups ||= groups_of(tests)
        end

        def read_groups
          @read_groups ||= content_groups_of(nodes_in(ast, :ivar))
        end

        def content_groups_of(nodes)
          {}.compare_by_identity.tap do |groups|
            nodes.each do |node|
              content_scopes_of(node).each { (groups[it] ||= []) << node }
            end
          end
        end

        def content_scopes_of(node)
          ContentDomains.new(node, domain_scope_index:, included_domains: included_domain_scopes).to_a
        end

        def domain_scope_index
          @domain_scope_index ||= {}.compare_by_identity.tap do |scopes|
            [ *setup_groups.keys, *test_groups.keys ].each { scopes[it] = true }
          end
        end

        def included_domain_scopes
          @included_domain_scopes ||= domain_scope_index.keys.select do |scope|
            any_block_type?(scope) && call_on_self?(call_of(scope)) && scope.method?(:included)
          end
        end

        def write_groups
          @write_groups ||= content_groups_of(nodes_in(ast, :ivasgn))
        end

        def setup_callback_groups
          @setup_callback_groups ||= groups_of(setup_callbacks)
        end

        def setup_callbacks
          nodes_in(ast, :send, :csend).select { call_on_self?(it) && it.method?(:setup) }
            .map { callback_node_for(it) }.sort_by { it.source_range.begin_pos }
        end

        def callback_node_for(call)
          if any_block_type?(call.parent) && call_of(call.parent).equal?(call)
            call.parent
          else
            call
          end
        end

        # A read or write belongs to the nearest active test domain, but an unopened class-like boundary owns its state
        # too. Concern helpers outside `included` share that block's runtime target without crossing nested owners.
        class ContentDomains
          include RuboCop::Callbacksystems::Helpers

          def initialize(node, domain_scope_index:, included_domains:)
            @node = node
            @domain_scope_index = domain_scope_index
            @included_domains = included_domains
          end

          def to_a
            {}.compare_by_identity.tap do |domains|
              primary_domain&.then { domains[it] = true }
              related_included_domains.each { domains[it] = true }
            end.keys
          end

          private
            attr_reader :node, :domain_scope_index, :included_domains

            def primary_domain
              nearest_domain_or_boundary if domain_scope_index.key?(nearest_domain_or_boundary)
            end

            def nearest_domain_or_boundary
              @nearest_domain_or_boundary ||= node.each_ancestor.find do |ancestor|
                domain_scope_index.key?(ancestor) || test_domain_boundary?(ancestor)
              end
            end

            def test_domain_boundary?(candidate)
              candidate.type?(:class, :module, :sclass) ||
                (any_block_type?(candidate) && self_rebinding_boundary?(candidate))
            end

            def related_included_domains
              included_domains.select do |scope|
                direct_owner_of(scope).equal?(direct_owner) &&
                  (!primary_domain || primary_domain.equal?(scope) || primary_domain.equal?(direct_owner))
              end
            end

            def direct_owner_of(subject)
              subject.each_ancestor.find { test_domain_boundary?(it) }
            end

            def direct_owner
              @direct_owner ||= direct_owner_of(node)
            end
        end
    end

    # One lexical test container, which excludes inherited setup and same-named variables in its neighbours.
    class TestDomain
      include RuboCop::Callbacksystems::Helpers

      def initialize(scope, setups:, context:)
        @scope = scope
        @setups = setups
        @context = context
      end

      def each_offense
        return if abstract_base_class?

        setups.each { setup_analysis_for(it).each_offense { yield it } }
      end

      private
        attr_reader :scope, :setups, :context

        delegate :tests, to: :context, private: true

        # A base class with no tests of its own hands its setup to subclasses that may live in other files.
        def abstract_base_class?
          scope.class_type? && rails_test_base_class?(scope.parent_class) && tests.empty?
        end

        def setup_analysis_for(setup)
          SetupBlock.new(setup, assignments: unambiguous_assignments.fetch(setup), context:)
        end

        def unambiguous_assignments
          @unambiguous_assignments ||= assignments_by_setup.transform_values do |assignments|
            assignments.reject { repeated_names.include?(it.name) }
          end
        end

        def assignments_by_setup
          @assignments_by_setup ||= {}.compare_by_identity.tap do |grouped|
            setups.each { grouped[it] = SetupAssignments.new(it.body, boundary: it).to_a }
          end
        end

        def repeated_names
          @repeated_names ||= assignments_by_setup.values.flatten.group_by(&:name)
            .select { |_name, assignments| assignments.many? }.keys
        end
    end

    class SetupBlock
      include RuboCop::Callbacksystems::Helpers

      def initialize(setup, assignments:, context:)
        @setup = setup
        @assignments = assignments
        @context = context
        @tooling_protection = ToolingProtection.new(setup, assignments, context.processed_source)
      end

      def each_offense
        offending.each { yield offense_for(it) }
      end

      private
        attr_reader :setup, :assignments, :context, :tooling_protection

        def offending
          @offending ||= assignments.map { assignment_for(it) }.select(&:offending?)
        end

        def assignment_for(node)
          SetupAssignment.new(node, setup:, context:, tooling_protection:)
        end

        def offense_for(assignment)
          if assignment.correctable?
            RuboCop::Callbacksystems::Offense.new(assignment.node, assignment.message) { correct(assignment, it) }
          else
            RuboCop::Callbacksystems::Offense.new(assignment.node, assignment.message)
          end
        end

        def correct(assignment, corrector)
          assignment.correct(corrector)
          removal_range_for(assignment)&.then { corrector.remove(it) }
        end

        def removal_range_for(assignment)
          if cleared?
            block_removal_range if assignment.equal?(first_removable)
          elsif assignment.removable?
            statement_removal_range_for(assignment.node)
          end
        end

        def cleared?
          removable.size == statements_in(setup.body).size
        end

        def removable
          @removable ||= offending.select(&:removable?)
        end

        def first_removable
          removable.min_by { it.node.source_range.begin_pos }
        end

        # The blank line below the block goes too, so the first test keeps its distance from the line above, and the
        # removal of a block written right below takes its own blank line instead of sharing this one.
        def block_removal_range
          inline_statement_removal_range_for(setup) || standalone_block_removal_range
        end

        def standalone_block_removal_range
          setup.source_range.with(begin_pos: line_start_position_of(setup), end_pos: position_past_trailing_blank)
        end

        def position_past_trailing_blank
          position_past_newline_at(position_past_newline_at(setup.source_range.end_pos))
        end

        def position_past_newline_at(position)
          newline_at?(position) ? position + 1 : position
        end

        def newline_at?(position)
          setup.source_range.source_buffer.source[position] == "\n"
        end
    end

    # Tooling comments cannot move with an assignment. A comment belonging to one assignment protects that assignment;
    # one belonging to the setup itself protects them all because removing the callback would change its scope.
    class ToolingProtection
      include RuboCop::Callbacksystems::Helpers

      def initialize(setup, assignments, processed_source)
        @setup = setup
        @assignments = assignments
        @processed_source = processed_source
        @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
      end

      def protects?(assignment)
        unassigned_tooling? || assignment_block_for(assignment).contains_tooling_comment?
      end

      private
        attr_reader :setup, :assignments, :processed_source, :source_comments

        def unassigned_tooling?
          tooling_comments.any? do |comment|
            assignment_blocks.values.none? { it.range.contains?(comment.source_range) }
          end
        end

        def tooling_comments
          @tooling_comments ||= source_comments.within(setup_block.range).select { tooling_comment?(it) }
        end

        def setup_block
          @setup_block ||= RuboCop::Callbacksystems::Source::StatementWithComments.new(setup, processed_source)
        end

        def assignment_blocks
          @assignment_blocks ||= {}.compare_by_identity.tap do |blocks|
            assignments.each do |assignment|
              blocks[assignment] = RuboCop::Callbacksystems::Source::StatementWithComments.new \
                assignment, processed_source
            end
          end
        end

        def assignment_block_for(assignment)
          assignment_blocks.fetch(assignment)
        end
    end

    class SetupAssignment
      include RuboCop::Callbacksystems::Helpers

      USED_ONCE_MESSAGE = "Instance variable `%<variable>s` is only used in one test. Inline it instead of assigning " \
        "in `setup`."
      UNUSED_MESSAGE = "Instance variable `%<variable>s` assigned in `setup` is not used by any test. Remove the " \
        "assignment."
      INLINABLE_TYPES = %i[
        int float rational complex str dstr sym dsym regexp true false nil self array hash const lvar ivar cvar gvar
      ]

      attr_reader :node

      def initialize(node, setup:, context:, tooling_protection:)
        @node = node
        @setup = setup
        @context = context
        @tooling_protection = tooling_protection
      end

      def offending?
        usage.unused? || usage.single_use?
      end

      def message
        format(usage.unused? ? UNUSED_MESSAGE : USED_ONCE_MESSAGE, variable: node.name)
      end

      def correct(corrector)
        if inline_target
          replace_expression(corrector, inline_target, with: value.source)
        elsif usage.unused? && !discardable_value?
          corrector.replace(node, value.source)
        end
      end

      def correctable?
        removable? || replaceable_unused_value?
      end

      def removable?
        source_self_contained? && !tooling_protection.protects?(node) && direct_statement? &&
          (inline_target || (usage.unused? && discardable_value?))
      end

      private
        attr_reader :setup, :context, :tooling_protection

        delegate :tests, :writes, to: :context, private: true

        def usage
          @usage ||= context.usage_of(node.name)
        end

        def inline_target
          usage.sole_direct_read if directly_inlinable?
        end

        def directly_inlinable?
          direct_statement? && stable_single_use? && relocation_safe?
        end

        def direct_statement?
          statements_in(setup.body).any? { it.equal?(node) }
        end

        def stable_single_use?
          sole_write? && single_use_of_inlinable_value?
        end

        def sole_write?
          writes.one? { it.name == node.name }
        end

        def single_use_of_inlinable_value?
          usage.single_use? && inlinable_value?
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
          value.arguments.empty? || value.parenthesized?
        end

        def relocation_safe?
          value.recursive_basic_literal? || relocation.safe?
        end

        def relocation
          @relocation ||= ValueRelocation.new(node, setup:, context:, read: usage.sole_direct_read)
        end

        def discardable_value?
          value.recursive_basic_literal?
        end

        def source_self_contained?
          !carries_heredoc?(node)
        end

        def replaceable_unused_value?
          direct_statement? && usage.unused? && !discardable_value?
        end

        # Moving an evaluated value between callbacks is only offered when every ordering fact visible in this file is
        # preserved. Calls remain intrinsically unsafe because external callbacks and their side effects are unknowable.
        class ValueRelocation
          include RuboCop::Callbacksystems::Helpers

          LAZY_ANCESTOR_TYPES = %i[
            and case case_match csend defined? ensure for if in_pattern or rescue resbody
            until until_post while while_post
          ]
          LOCAL_BINDING_TYPES = %i[ lvar lvasgn match_var ]

          def initialize(assignment, setup:, context:, read:)
            @assignment = assignment
            @setup = setup
            @context = context
            @read = read
          end

          def safe?
            read && keeps_scope? && follows_visible_setup_work? && eagerly_leads_test_work?
          end

          private
            attr_reader :assignment, :setup, :context, :read

            delegate :setup_callbacks, :tests, to: :context, private: true

            def keeps_scope?
              nodes_in(assignment.expression, *LOCAL_BINDING_TYPES).empty?
            end

            def follows_visible_setup_work?
              setup_callbacks.last.equal?(setup) && statements_in(setup.body).last.equal?(assignment)
            end

            def eagerly_leads_test_work?
              tests.any? { it.equal?(test) } && lazy_ancestors.empty? && prior_effects.empty?
            end

            def test
              @test ||= read.each_ancestor(:any_block).first
            end

            def lazy_ancestors
              evaluation_path.select { it.type?(*LAZY_ANCESTOR_TYPES) }
            end

            def evaluation_path
              @evaluation_path ||= read.each_ancestor.take_while { !it.equal?(test) }
            end

            def prior_effects
              current = read
              evaluation_path.flat_map do |ancestor|
                ancestor.child_nodes.take_while { !it.equal?(current) }.reject(&:recursive_basic_literal?).tap do
                  current = ancestor
                end
              end
            end
        end
    end

    # All reads in a test domain are indexed once, then every setup assignment asks only for its own variable.
    class InstanceVariableUsages
      def initialize(reads, tests:)
        @test_membership = TestMembership.new(tests)
        @reads_by_name = {}
        @usages = {}

        reads.each do |read|
          (reads_by_name[read.name] ||= []) << read
          test_membership.index(read)
        end
      end

      def for(variable_name)
        usages[variable_name] ||= InstanceVariableUsage.new(reads_by_name.fetch(variable_name, []), test_membership:)
      end

      private
        attr_reader :reads_by_name, :test_membership, :usages

        class TestMembership
          Membership = Data.define(:tests, :direct)

          def initialize(tests)
            @test_index = {}.compare_by_identity
            @memberships = {}.compare_by_identity
            tests.each { test_index[it] = true }
          end

          def index(read)
            memberships[read] = membership_of(read)
          end

          def all_inside?(reads)
            reads.all? { memberships.fetch(it).tests.any? }
          end

          def one_test_for?(reads)
            reads.each_with_object({}.compare_by_identity) do |read, reading_tests|
              memberships.fetch(read).tests.each { reading_tests[it] = true }
            end.one?
          end

          def direct?(read)
            memberships.fetch(read).direct
          end

          private
            attr_reader :memberships, :test_index

            def membership_of(read)
              nearest_block = nil
              tests = read.each_ancestor(:any_block).with_object([]) do |block, containing_tests|
                nearest_block ||= block
                containing_tests << block if test_index.key?(block)
              end

              Membership.new(tests, test_index.key?(nearest_block))
            end
        end
    end

    class InstanceVariableUsage
      def initialize(reads, test_membership:)
        @reads = reads
        @test_membership = test_membership
      end

      def unused?
        reads.none?
      end

      # A read outside the tests, in a helper or a teardown, keeps the variable shared however few tests read it.
      def single_use?
        test_membership.all_inside?(reads) && test_membership.one_test_for?(reads)
      end

      # A read inside a block of its test would run the value again, so only a direct read counts as the one read.
      def sole_direct_read
        sole_read if sole_read && test_membership.direct?(sole_read)
      end

      private
        attr_reader :reads, :test_membership

        def sole_read
          reads.first if reads.one?
        end
    end

    # Instance-variable assignments executed by a setup, without descending through a deferred lexical boundary.
    class SetupAssignments
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, boundary: nil)
        @body = body
        @boundary = boundary
      end

      def each
        assignments.each { yield it } if block_given?
        to_enum(__method__) unless block_given?
      end

      private
        attr_reader :body, :boundary

        def assignments
          RuboCop::Callbacksystems::Execution::Immediate.new(body).nodes_of_type(:ivasgn)
            .select { it.expression && self_preserved_between?(it, boundary:) }
        end
    end
end
