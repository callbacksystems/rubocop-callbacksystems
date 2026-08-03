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

  MESSAGE = "Put `end` on its own line."

  def on_class(node)
    definition = SingleLineDefinition.new(node)
    add_offense(node, message: MESSAGE) { definition.expand(it) } if definition.offense?
  end

  alias on_module on_class

  private
    class SingleLineDefinition
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        node.body.nil? && node.single_line? && stays_a_definition?
      end

      def expand(corrector)
        corrector.replace(gap_before_end, "\n#{indentation_of(node)}")
      end

      private
        attr_reader :node

        # A nested empty class becomes a constant, so its own rule has the last word.
        def stays_a_definition?
          node.module_type? || enclosing_class_or_module_of(node).nil?
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
