# `delegate ... private: true` declares private methods, so it belongs in the
# private section next to the other private declarations. Left above, it hides
# private methods among the public API; left below the section's methods, it
# hides a declaration among behavior.
#
# @example
#   # bad
#   class Report
#     delegate :total, to: :order, private: true
#
#     def to_s
#       total.to_s
#     end
#
#     private
#       attr_reader :order
#   end
#
#   # bad - below the methods of its section
#   class Report
#     private
#       def formatted_total
#         total.to_s
#       end
#
#       delegate :total, to: :order, private: true
#   end
#
#   # good
#   class Report
#     def to_s
#       total.to_s
#     end
#
#     private
#       attr_reader :order
#       delegate :total, to: :order, private: true
#   end
#
class RuboCop::Cop::Callbacksystems::PrivateDelegatePlacement < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report Delegate.new(node, processed_source)
  end

  alias on_csend on_send

  private
    class Delegate
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Move this `delegate` into the private section; it declares private methods."
      STRAYED_MESSAGE = "Move this `delegate` up beside the other private declarations."

      def initialize(node, processed_source)
        @node = node
        @processed_source = processed_source
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message, correcting: correctable?) { correct(it) } if misplaced?
      end

      private
        attr_reader :node, :processed_source

        def misplaced?
          private_delegate? && statements.include?(node) && !placed_with_declarations?
        end

        def private_delegate?
          macro.macro? && macro.private?
        end

        def macro
          @macro ||= RuboCop::Callbacksystems::Methods::DelegateMacro.new(node)
        end

        def statements
          @statements ||= statements_in(enclosing_body)
        end

        def enclosing_body
          @enclosing_body ||= enclosing_definition_of(node)&.body
        end

        def placed_with_declarations?
          declarations_after_private_modifier.include?(node)
        end

        def declarations_after_private_modifier
          statements_after_private_modifier.take_while { declaration?(it) }
        end

        def statements_after_private_modifier
          private_modifier ? statements.drop(statements.index(private_modifier) + 1) : []
        end

        def private_modifier
          @private_modifier ||= private_modifier_in(enclosing_body)
        end

        def declaration?(statement)
          statement.casgn_type? || declaration_macro?(statement)
        end

        def message
          outside_private_section? ? MESSAGE : STRAYED_MESSAGE
        end

        def outside_private_section?
          visibility_at(node, enclosing_body) != :private
        end

        def correctable?
          movement_safe? && relocation_safe?
        end

        def movement_safe?
          !blocked_by_constant? && !blocked_by_method_definition? && !blocked_by_comment? &&
            !blocked_by_executable_statement? && tooling_scope_kept?
        end

        # Moving up over the assignment of a constant the delegate reads would break the class at load time.
        def blocked_by_constant?
          referenced_constant_names.intersect?(constant_names_crossed_moving_up)
        end

        def referenced_constant_names
          node.arguments.flat_map { it.each_node(:const).map(&:short_name) }
        end

        def constant_names_crossed_moving_up
          if anchor_index && anchor_index < node_index
            statements[(anchor_index + 1)...node_index].select(&:casgn_type?).map(&:name)
          else
            []
          end
        end

        def anchor_index
          statements.index(anchor)
        end

        def anchor
          declarations_after_private_modifier.last || private_modifier || statements.excluding(node).last
        end

        def node_index
          statements.index(node)
        end

        # Swapping two declarations of the same method would change which implementation the class keeps.
        def blocked_by_method_definition?
          names = macro.defined_method_names&.to_set
          crossed_names = method_names_defined_by(crossed_statements)

          names.nil? || crossed_names.nil? || names.intersect?(crossed_names)
        end

        def method_names_defined_by(found)
          names = found.map { RuboCop::Callbacksystems::Methods::StatementDefinitions.new(it).names }

          names.flat_map(&:to_a).to_set if names.none?(&:nil?)
        end

        def crossed_statements
          if anchor_index
            if node_index < anchor_index
              statements[(node_index + 1)..anchor_index]
            else
              statements[(anchor_index + 1)...node_index]
            end
          else
            []
          end
        end

        def blocked_by_comment?
          movement_blocks.each_cons(2).any? do |above, below|
            above.range.end.join(below.range.begin).source.strip.present?
          end
        end

        def movement_blocks
          movement_statements.map { RuboCop::Callbacksystems::Source::StatementWithComments.new(it, processed_source) }
        end

        def movement_statements
          if anchor_index
            first, last = [ node_index, anchor_index ].minmax
            statements[first..last]
          else
            [ node ]
          end
        end

        # Method bodies do not run while the class loads. Unknown statements do, so their relative order is kept.
        def blocked_by_executable_statement?
          crossed_statements.any? { !movable_across?(it) }
        end

        def movable_across?(statement)
          statement.type?(:def, :defs) || visibility_modifier_of(statement) || declaration_macro?(statement)
        end

        def tooling_scope_kept?
          movement_blocks.none?(&:contains_tooling_comment?)
        end

        def relocation_safe?
          relocation_ranges_proven? && relocated_source.possible?
        end

        def relocation_ranges_proven?
          statement_owns_line?(node) && (!anchor || statement_owns_line?(anchor))
        end

        def statement_owns_line?(statement)
          StatementLine.new(statement).owned?
        end

        def relocated_source
          @relocated_source ||= RelocatedSource.new(block, to: section_indentation)
        end

        def block
          @block ||= RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def section_indentation
          statements_after_private_modifier.first&.then { indentation_of(it) } ||
            "#{body_indentation}#{indentation_step}"
        end

        def body_indentation
          indentation_of(statements.first)
        end

        def indentation_step
          " " * (statements.first.source_range.column - enclosing_definition_of(node).source_range.column)
        end

        def correct(corrector)
          if anchor
            corrector.insert_after(anchor_block.range, relocated_delegate)
            corrector.remove(statement_removal_range_of(block.range))
          else
            corrector.replace(block.range, private_section)
          end
        end

        def anchor_block
          @anchor_block ||= RuboCop::Callbacksystems::Source::StatementWithComments.new(anchor, processed_source)
        end

        def relocated_delegate
          private_modifier ? indented_delegate : "\n\n#{body_indentation}private#{indented_delegate}"
        end

        def indented_delegate
          "\n#{relocated_source.source}"
        end

        def private_section
          "#{body_indentation}private#{indented_delegate}"
        end
    end

    # Whether a statement range can be moved without consuming code that shares either edge line.
    class StatementLine
      def initialize(node)
        @node = node
      end

      def owned?
        code_before.strip.empty? && (code_after.strip.empty? || code_after.lstrip.start_with?("#"))
      end

      private
        attr_reader :node

        def code_before
          node.source_range.source_line[0...node.source_range.column]
        end

        def code_after
          node.source_range.end.source_line[node.source_range.end.column..]
        end
    end

    # Source shifted by one indentation delta, with relative whitespace and heredoc contents left intact.
    class RelocatedSource
      def initialize(statement, to:)
        @statement = statement
        @target_indentation = to
      end

      def possible?
        indentation_removable? && heredocs_preserved?
      end

      def source
        lines.map { reindented(it) }.join
      end

      private
        attr_reader :statement, :target_indentation

        def indentation_removable?
          delta >= 0 || lines.all? { it.strip.empty? || it.start_with?(removed_indentation) }
        end

        def delta
          target_indentation.length - statement.node.source_range.column
        end

        def lines
          @lines ||= statement.source.lines
        end

        def removed_indentation
          " " * -delta
        end

        def heredocs_preserved?
          delta.zero? || heredocs.all? { it.source.start_with?("<<~") }
        end

        def heredocs
          statement.node.each_node(:str, :dstr, :xstr).select { it.loc?(:heredoc_body) }
        end

        def reindented(line)
          if line.strip.empty? then line
          elsif delta.positive? then "#{" " * delta}#{line}"
          else line.delete_prefix(removed_indentation)
          end
        end
    end
end
