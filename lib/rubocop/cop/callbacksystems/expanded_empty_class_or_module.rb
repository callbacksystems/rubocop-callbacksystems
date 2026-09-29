# An empty class or module keeps its `end` on a line of its own, the way
# `Style/EmptyMethod` already asks of an empty method.
#
# A nested empty class is left to `PreferClassNewForEmptyNestedClass`, which
# turns it into a constant rather than a definition.
#
# @example
#   # bad
#   class PgBox::ConfigurationError < StandardError; end
#
#   # good
#   class PgBox::ConfigurationError < StandardError
#   end
#
class RuboCop::Cop::Callbacksystems::ExpandedEmptyClassOrModule < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    report SingleLineDefinition.new(node)
  end

  alias on_module on_class

  private
    class SingleLineDefinition
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Put `end` on its own line."

      def initialize(node)
        @node = node
      end

      def offense
        if expandable?
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: superclass_without_heredoc?) { correct(it) }
        end
      end

      private
        attr_reader :node

        def expandable?
          node.body.nil? && node.single_line? && stays_a_definition?
        end

        def stays_a_definition?
          node.module_type? || enclosing_class_or_module_of(node).nil?
        end

        def superclass_without_heredoc?
          node.module_type? || node.parent_class.nil? || !carries_heredoc?(node.parent_class)
        end

        def correct(corrector)
          corrector.replace(gap_before_end, "\n#{indentation_of(node)}")
        end

        def gap_before_end
          node.source_range.with(begin_pos: header_end, end_pos: node.loc.end.begin_pos)
        end

        def header_end
          (superclass || node.identifier).source_range.end_pos
        end

        def superclass
          node.parent_class if node.class_type?
        end
    end
end
