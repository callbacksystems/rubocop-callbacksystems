# Prefers backslash line continuation over parentheses for a call that `Layout/LineLength` keeps off a single line.
# The backslash leaves the arguments as a plain list below the call, one per line and with nothing to close them,
# which is how a long call reads best. A call that would fit on one line belongs there instead, which
# `Callbacksystems/CollapseMultilineExpression` asks for, so this one stays quiet about it.
#
# @example
#   # bad - multiline with parentheses
#   claim = Account::Invitation::Claim.new(
#     invitation: invitations(:bruno),
#     name: "Test User"
#   )
#
#   # good - multiline with backslash
#   claim = Account::Invitation::Claim.new \
#     invitation: invitations(:bruno),
#     name: "Test User"
#
#   # good - short enough for one line
#   claim = Claim.new(
#     name: "Test User"
#   )
#
#   # bad - first argument left up on the opening line
#   preference = Payment::Preference.create(client,
#     items: items)
#
#   # good - every argument below the backslash
#   preference = Payment::Preference.create \
#     client,
#     items: items
#
#   # good - method call without parentheses
#   redirect_to account_path, notice: t(".success")
#
#   # good - nested call (a backslash inside parentheses would take the outer commas)
#   update!(time_block: Model.find_or_create_by!(
#     starts_at: starts_at, ends_at: ends_at
#   ))
#
#   # bad - the last argument of a bare command, whose commas can only be its own
#   get availability_path(
#     line_item, rule_id: rule.id, sid: cart.signed_id
#   )
#
#   # good
#   get availability_path \
#     line_item, rule_id: rule.id, sid: cart.signed_id
#
#   # good - block disambiguation (without parens block goes to outer method)
#   concat(tag.div do
#     content
#   end)
#
#   # good - a call handing over a block
#   link_to(notification,
#     class: classes,
#     &)
#
#   # good - an argument runs past the opening line
#   selections.add(rule: rule, params: {
#     starts_at: starts_at
#   })
#
class RuboCop::Cop::Callbacksystems::PreferBackslashContinuation < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
    @structural_contents = StructuralContents.new(processed_source.ast)
  end

  def on_send(node)
    report MethodCall.new(node, processed_source, source_comments:, structural_contents:, max_line_length:)
  end

  alias on_csend on_send

  private
    attr_reader :source_comments, :structural_contents

    # Structural facts indexed bottom-up once, rather than rediscovering a nested call or block from every ancestor.
    class StructuralContents
      def initialize(root)
        @root = root
      end

      def multiline_call_within?(node)
        multiline_calls.within?(node)
      end

      def block_within?(node)
        blocks.within?(node)
      end

      def forwarded_arguments_in?(node)
        forwarded_arguments.including?(node)
      end

      private
        attr_reader :root

        def multiline_calls
          @multiline_calls ||= Descendants.new(root, :multiline_call)
        end

        def blocks
          @blocks ||= Descendants.new(root, :block)
        end

        def forwarded_arguments
          @forwarded_arguments ||= Descendants.new(root, :forwarded_argument)
        end

        # One kind of structural node and the ancestors whose subtrees contain it.
        class Descendants
          include RuboCop::Callbacksystems::Helpers

          def initialize(root, kind)
            @root = root
            @kind = kind
          end

          def within?(node)
            node.each_child_node.any? { including?(it) }
          end

          def including?(node)
            matching_subtrees.key?(node)
          end

          private
            attr_reader :root, :kind

            def matching_subtrees
              @matching_subtrees ||= nodes_in(root).reverse_each.with_object({}.compare_by_identity) do |node, matches|
                matches[node] = true if matching_node?(node) || node.each_child_node.any? { matches.key?(it) }
              end
            end

            def matching_node?(node)
              case kind
              when :multiline_call then multiline_send?(node)
              when :block then any_block_type?(node)
              when :forwarded_argument then node.type?(:forwarded_restarg, :forwarded_kwrestarg)
              else false
              end
            end

            def multiline_send?(node)
              node.type?(:send, :csend) && node.arguments? && node.loc.begin && node.loc.end &&
                !same_line?(node.loc.begin, node.loc.end)
            end
        end
    end

    class MethodCall
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Use `\\` for line continuation instead of wrapping arguments in parentheses."
      INDENTATION = "  "
      NOTHING_BUT_THE_PARENTHESIS = /\A[\s,]*\)\z/
      COMMA_AFTER_ARGUMENTS = /\A[ \t]*,/

      def initialize(node, processed_source, source_comments:, structural_contents:, max_line_length:)
        @node = node
        @processed_source = processed_source
        @source_comments = source_comments
        @structural_contents = structural_contents
        @max_line_length = max_line_length
      end

      def offense
        if wrapped_in_parentheses?
          RuboCop::Callbacksystems::Offense.new(node.loc.begin, MESSAGE, correcting: correctable?) { correct(it) }
        end
      end

      private
        attr_reader :node, :processed_source, :source_comments, :structural_contents, :max_line_length

        def wrapped_in_parentheses?
          node.parenthesized? && multiline_send?(node) && !allowed?
        end

        def multiline_send?(send_node)
          send_node.arguments? && send_node.loc.begin && send_node.loc.end &&
            !same_line?(send_node.loc.begin, send_node.loc.end)
        end

        def allowed?
          belongs_on_one_line? || braces_still_settling? || inside_other_expression? ||
            unconvertible_arguments? || carries_a_block? || opening_comment_destination_occupied?
        end

        def belongs_on_one_line?
          RuboCop::Callbacksystems::Source::SingleLineCall.new(node, max_line_length).fits?
        end

        # `Layout/MultilineMethodCallBraceLayout` still moves that parenthesis, and two rewrites in one pass break it.
        def braces_still_settling?
          first_argument_on_opening_line? && parenthesis_alone_on_its_line?
        end

        def first_argument_on_opening_line?
          first_argument_line == opening_line
        end

        def first_argument_line
          node.first_argument.first_line
        end

        def opening_line
          node.loc.begin.line
        end

        def parenthesis_alone_on_its_line?
          node.loc.end.source_line.strip == ")"
        end

        def inside_other_expression?
          enclosing_syntax.commas_claimed_by_a_list? || inside_backslash_continuation? ||
            enclosing_syntax.part_of_a_larger_expression?
        end

        def enclosing_syntax
          @enclosing_syntax ||= EnclosingSyntax.new(node)
        end

        def inside_backslash_continuation?
          previous_line(node.loc.begin.line)&.rstrip&.end_with?("\\")
        end

        def previous_line(line)
          processed_source.lines[line - 2] if line > 1
        end

        def unconvertible_arguments?
          argument_has_block? || contains_multiline_call? || leading_braced_hash? ||
            opening_line_ends_inside_an_argument? || control_flow_argument? || forwards_anonymous_arguments?
        end

        def argument_has_block?
          direct_block_argument? || nested_block_in_arguments?
        end

        def direct_block_argument?
          node.arguments.any? { hands_over_a_block?(it) }
        end

        # Ruby reads a `&` as ambiguous when nothing precedes it on the line, which is where a continuation puts it.
        def hands_over_a_block?(argument)
          any_block_type?(argument) || argument.block_pass_type?
        end

        def nested_block_in_arguments?
          node.arguments.any? { structural_contents.block_within?(it) }
        end

        def contains_multiline_call?
          structural_contents.multiline_call_within?(node)
        end

        def leading_braced_hash?
          node.first_argument.source.start_with?("{")
        end

        # The lines such an argument spans are indented against a parenthesis that is going away.
        def opening_line_ends_inside_an_argument?
          node.arguments.any? { it.first_line == opening_line && it.last_line > opening_line }
        end

        def control_flow_argument?
          node.arguments.any? { it.type?(:if, :case, :case_match, :while, :until) }
        end

        def forwards_anonymous_arguments?
          node.arguments.any? { structural_contents.forwarded_arguments_in?(it) }
        end

        def carries_a_block?
          any_block_type?(node.parent) && node.parent.send_node.equal?(node)
        end

        # The opening comment normally moves after the last argument. If that position already carries a comment,
        # combining them would turn two comments into one and standing either between the continuation lines breaks it.
        def opening_comment_destination_occupied?
          opening_comment && follows_last_argument?(source_comments.trailing_comment_on(last_argument_end.line))
        end

        def opening_comment
          @opening_comment ||= source_comments.trailing_comment_on(opening_line)&.then { it if follows_opening?(it) }
        end

        def follows_opening?(comment)
          same_line?(comment, node.loc.begin) && node.loc.begin.end.join(comment.source_range.begin).source.blank?
        end

        def follows_last_argument?(comment)
          comment && comment.loc.line == last_argument_end.line &&
            comment.source_range.begin_pos >= last_argument_end.begin_pos
        end

        # The opener of a heredoc can take a comment, its terminator cannot.
        def last_argument_end
          node.last_argument.source_range.end
        end

        def correctable?
          opening_comment_movable? && arguments_uncommented? &&
            (parenthesis_alone_on_its_line? || (closing_parenthesis_stands_alone? && comments_undisturbed?))
        end

        def opening_comment_movable?
          opening_comment.nil? || !tooling_comment?(opening_comment)
        end

        # After a backslash the next line is joined to the call, so a comment above the first argument would swallow it.
        def arguments_uncommented?
          !source_comments.any_on_lines?((node.loc.begin.line + 1)..(first_argument_line - 1))
        end

        def closing_parenthesis_stands_alone?
          trailing_parenthesis_range.source.match?(NOTHING_BUT_THE_PARENTHESIS)
        end

        def trailing_parenthesis_range
          arguments_end.join(node.loc.end)
        end

        def arguments_end
          node.arguments.map { range_through_heredocs(it) }.max_by(&:end_pos).end
        end

        def comments_undisturbed?
          !orphaned?(source_comments.trailing_comment_on(node.loc.end.line))
        end

        def orphaned?(comment)
          comment && same_line?(comment, node.loc.end) && comment.source_range.begin_pos >= node.loc.end.end_pos
        end

        def correct(corrector)
          corrector.replace(opening, continuation)
          expand_trailing_shorthand(corrector)
          corrector.insert_after(last_argument_end, " #{opening_comment.text}") if opening_comment
          removals.each { corrector.remove(it) }
        end

        # A comment written right after the parenthesis cannot follow a backslash, so it closes the arguments instead.
        def opening
          opening_comment ? node.loc.begin.join(opening_comment.source_range) : node.loc.begin
        end

        def continuation
          first_argument_on_opening_line? ? " \\\n#{argument_indentation}" : " \\"
        end

        def argument_indentation
          node.loc.begin.source_line[/\A\s*/] + INDENTATION
        end

        # Without the closing parenthesis, a final `option:` can take the expression on the next line as its value.
        def expand_trailing_shorthand(corrector)
          trailing_shorthand&.then { corrector.insert_after(it, " #{it.value.source}") }
        end

        def trailing_shorthand
          trailing_pair if trailing_pair&.value_omission?
        end

        def trailing_pair
          @trailing_pair ||= node.last_argument.then { it.pairs.last if it.hash_type? }
        end

        # Taking the whole line leaves a comment above the parenthesis where it was, which cutting back would not.
        def removals
          parenthesis_alone_on_its_line? ? [ trailing_comma, parenthesis_line ].compact : [ trailing_parenthesis_range ]
        end

        # The parenthesis is what kept a trailing comma legal, so it goes along.
        def trailing_comma
          match = COMMA_AFTER_ARGUMENTS.match(trailing_parenthesis_range.source)
          arguments_end.adjust(end_pos: match.to_s.length) if match
        end

        def parenthesis_line
          line_removal_range_of(node.loc.end)
        end
    end

    # The ancestor syntax that would claim the commas or make a bare continued call parse differently.
    class EnclosingSyntax
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def commas_claimed_by_a_list?
        nested_in_call? || inside_parameter_list? || inside_collection_literal? || matched_by_a_when?
      end

      def part_of_a_larger_expression?
        chained_method_receiver? || operand_of_boolean? || branch_of_one_line_conditional? ||
          assigned_inside_a_condition? || endpoint_of_range? || matched_as_a_pattern? || constant_namespace?
      end

      private
        attr_reader :node

        def nested_in_call?
          enclosing_calls.any? { !last_argument_of_bare_command?(it) }
        end

        def enclosing_calls
          node.each_ancestor(:send, :csend, :super, :yield).select { |call| call.arguments.any? { holds?(it) } }
        end

        def holds?(other)
          other.equal?(node) || ancestor_nodes.key?(other)
        end

        def ancestor_nodes
          @ancestor_nodes ||= {}.compare_by_identity.tap do |ancestors|
            node.each_ancestor { ancestors[it] = true }
          end
        end

        # A bare command ending in this call leaves the commas to it, so only there the backslash reads right.
        def last_argument_of_bare_command?(call)
          !call.parenthesized? && call.last_argument.equal?(node)
        end

        def inside_parameter_list?
          node.each_ancestor(:args).any?
        end

        def inside_collection_literal?
          node.each_ancestor(:hash, :array).any?
        end

        def matched_by_a_when?
          node.each_ancestor(:when).any? { |branch| branch.conditions.any? { holds?(it) } }
        end

        def chained_method_receiver?
          node.parent&.call_type? && node.parent.receiver == node
        end

        def operand_of_boolean?
          node.each_ancestor(:and, :or).any?
        end

        def branch_of_one_line_conditional?
          node.each_ancestor(:if).any? { it.ternary? || it.modifier_form? }
        end

        # Ruby rejects a call without parentheses as the value of an assignment that a condition tests.
        def assigned_inside_a_condition?
          node.each_ancestor(:if, :while, :until).any? { it.condition.assignment? && holds?(it.condition) }
        end

        # A command-style call consumes a following range operator as part of its final argument.
        def endpoint_of_range?
          node.each_ancestor(:irange, :erange).any?
        end

        # The command form would make `=>` or `in` bind to the final argument rather than the call's result.
        def matched_as_a_pattern?
          node.each_ancestor(:match_pattern, :match_pattern_p).any?
        end

        # The command form would make `::Name` qualify the final argument instead of the call's result.
        def constant_namespace?
          node.each_ancestor(:const).any? { holds?(it.namespace) }
        end
    end
end
