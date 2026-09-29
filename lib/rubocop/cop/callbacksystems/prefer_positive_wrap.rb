# A negative `return unless` guard followed by a happy path reads more naturally
# as `if condition; ...; end`. The wrap adds one `if` block, so it is only applied when
# the happy path's own nesting plus that extra level still fits inside the
# configured `Metrics/BlockNesting` limit; anything past that would push the
# method past the nesting limit. Method-length rules already cap how long a
# happy path can be, so the only real cost of the wrap is the indent level it adds.
#
# @example
#   # bad - leading negative guard
#   def label
#     return unless ready?
#     compute_label
#   end
#
#   # good - positive wrap
#   def label
#     if ready?
#       compute_label
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferPositiveWrap < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_def(node)
    report Guard.new(node.body, processed_source, nesting: block_nesting)
  end

  alias on_defs on_def

  private
    def block_nesting
      BlockNesting.new(config.for_cop("Metrics/BlockNesting"))
    end

    # The configured core metric, reduced to the one question this rewrite needs to ask.
    class BlockNesting
      NESTING_TYPES = %i[ case case_match if while while_post until until_post for resbody ].to_set

      def initialize(config)
        @max = config["Max"]
        @count_blocks = config.fetch("CountBlocks", false)
        @count_modifier_forms = config.fetch("CountModifierForms", false)
      end

      def allows_wrap?(nodes)
        nodes.map { depth_of(it) }.max.to_i + 1 <= max
      end

      private
        attr_reader :max, :count_blocks, :count_modifier_forms

        def depth_of(node)
          {}.compare_by_identity.then do |depths|
            Descendants.new(node).to_a.reverse_each do |descendant|
              depths[descendant] = (counts?(descendant) ? 1 : 0) +
                descendant.each_child_node.map { depths.fetch(it) }.max.to_i
            end
            depths.fetch(node)
          end
        end

        def counts?(node)
          NESTING_TYPES.include?(node.type) ? counts_control_flow?(node) : count_blocks && node.any_block_type?
        end

        def counts_control_flow?(node)
          !node.if_type? || counts_if?(node)
        end

        def counts_if?(node)
          !node.elsif? && (!node.modifier_form? || count_modifier_forms)
        end

        class Descendants
          include Enumerable

          def initialize(root)
            @root = root
          end

          def each
            if block_given?
              pending = [ root ]
              until pending.empty?
                node = pending.pop
                yield node
                pending.concat(node.each_child_node.to_a.reverse)
              end
            else
              to_enum(__method__)
            end
          end

          private
            attr_reader :root
        end
    end

    # The leading negative guard inside a method body, plus the happy path that follows it.
    class Guard
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Wrap positively: `if condition; ...; end` instead of a leading negative guard."

      def initialize(body, processed_source, nesting:)
        @body = body
        @processed_source = processed_source
        @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
        @nesting = nesting
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(guard, MESSAGE, correcting: correctable?) { correct(it) } if wrappable?
      end

      private
        attr_reader :body, :processed_source, :source_comments, :nesting

        def wrappable?
          statements.size >= 2 && negative_return_guard?(guard) && nesting.allows_wrap?(happy)
        end

        def statements
          statements_in(body)
        end

        def negative_return_guard?(node)
          node.if_type? && node.unless? && node.if_branch&.return_type?
        end

        def guard
          statements.first
        end

        def happy
          statements.drop(1)
        end

        # An existing `else` is observable on the positive path and cannot be folded into this rewrite.
        def correctable?
          guard_shape_correctable? && rewrite_preserves_source?
        end

        def guard_shape_correctable?
          guard.else_branch.nil? && guard_value_stands_alone?
        end

        def guard_value_stands_alone?
          guard_values.size != 1 || !unpackaged_splat?(guard_values.first)
        end

        def guard_values
          guard.if_branch.children
        end

        def unpackaged_splat?(value)
          value.splat_type? || (value.hash_type? && !value.braces?)
        end

        def rewrite_preserves_source?
          comments_preserved? && heredocs_preserved?
        end

        def comments_preserved?
          comments_in_replacement.all? { preserved_comment?(it) }
        end

        def comments_in_replacement
          source_comments.within(replacement_range)
        end

        def replacement_range
          guard.source_range.with(end_pos: happy_range.end_pos)
        end

        def happy_range
          @happy_range ||= first_happy_block.range.with(end_pos: last_happy_block.range.end_pos)
        end

        def first_happy_block
          @first_happy_block ||= statement_block_for(happy.first)
        end

        def statement_block_for(node)
          RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def last_happy_block
          @last_happy_block ||= statement_block_for(happy.last)
        end

        def preserved_comment?(comment)
          comment.equal?(guard_trailing_comment) || preserved_comment_ranges.any? { it.contains?(comment.source_range) }
        end

        def guard_trailing_comment
          @guard_trailing_comment ||= source_comments.trailing_comment_on(guard.last_line)
        end

        def preserved_comment_ranges
          [ happy_range, guard.condition.source_range, *guard_values.map(&:source_range) ]
        end

        def heredocs_preserved?
          !carries_heredoc?(guard) && happy_heredocs.all? { it.source.start_with?("<<~") }
        end

        def happy_heredocs
          happy.flat_map { it.each_node(:str, :dstr, :xstr).select { it.loc?(:heredoc_body) } }
        end

        def correct(corrector)
          corrector.replace(replacement_range, wrapped_source)
        end

        def wrapped_source
          "#{guard_header}\n#{indented_happy}\n#{else_branch}#{indent}end"
        end

        def guard_header
          "if #{guard.condition.source}#{guard_comment_source}"
        end

        def guard_comment_source
          guard_trailing_comment&.then { " #{it.text}" }.to_s
        end

        def indented_happy
          [ "#{first_line_indent}#{happy_lines.first}", *happy_lines.drop(1).map { indented_line(it) } ].join
        end

        def first_line_indent
          happy_range.column.zero? ? "  " : "#{indent}  "
        end

        def indent
          indentation_of(guard)
        end

        def happy_lines
          @happy_lines ||= happy_source.lines
        end

        def happy_source
          happy_range.source
        end

        def indented_line(line)
          line.strip.empty? ? line : "  #{line}"
        end

        def else_branch
          guard_value_source ? "#{indent}else\n#{indent}  #{guard_value_source}\n" : ""
        end

        def guard_value_source
          case guard_values
          in [] then nil
          in [ value ] then value.source
          else "[ #{guard_values.map(&:source).join(", ")} ]"
          end
        end
    end
end
