# A statement together with the comments that read as its own: the contiguous own-line comments right above it and the
# comment closing its last line. A rewrite that moves the statement moves them, and a range spanning it spans them.
class RuboCop::Callbacksystems::Source::StatementWithComments
  include RuboCop::Callbacksystems::Helpers

  attr_reader :node

  delegate :source, to: :range

  class << self
    def sibling_lines_for(processed_source)
      SIBLING_LINES_LOCK.synchronize { SIBLING_LINES[processed_source.comments] ||= SiblingLines.new }
    end

    private
      SIBLING_LINES = ObjectSpace::WeakMap.new
      SIBLING_LINES_LOCK = Mutex.new
  end

  def initialize(node, processed_source)
    @node = node
    @processed_source = processed_source
    @source_comments = RuboCop::Callbacksystems::Source::Comments.for(processed_source)
    @sibling_lines = self.class.sibling_lines_for(processed_source)
  end

  def contains_tooling_comment?
    source_comments.tooling_within?(range)
  end

  def range
    @range ||= range_between(begin_position, end_position)
  end

  def begin_position
    @begin_position ||=
      previous_statement_on_line? ? node.source_range.begin_pos : line_start_position_of(leading_comments.first || node)
  end

  private
    attr_reader :processed_source, :source_comments, :sibling_lines

    def previous_statement_on_line?
      sibling_lines.previous_on_line?(node)
    end

    def leading_comments
      @leading_comments ||= comments_above(node.first_line - 1)
    end

    def comments_above(first_line)
      comments = []
      line = first_line
      while (comment = source_comments.own_line_comment_on(line))
        comments << comment
        line -= 1
      end
      comments.reverse
    end

    def end_position
      [ range_through_heredocs(node).end_pos, trailing_comment&.source_range&.end_pos ].compact.max
    end

    def trailing_comment
      source_comments.trailing_comment_on(node.last_line) unless following_statement_on_line?
    end

    def following_statement_on_line?
      sibling_lines.following_on_line?(node)
    end

    # Same-line sibling relationships indexed without retaining AST nodes beyond the processed source's lifetime.
    class SiblingLines
      def initialize
        @relationships = {}
        @indexed_parents = Set.new
      end

      def previous_on_line?(node)
        relationship_for(node).first
      end

      def following_on_line?(node)
        relationship_for(node).last
      end

      private
        attr_reader :relationships, :indexed_parents

        def relationship_for(node)
          index(node.parent)
          relationships.fetch(key_of(node)) { [ false, false ] }
        end

        def index(parent)
          if parent&.type?(:begin, :kwbegin) && indexed_parents.add?(key_of(parent))
            siblings = parent.each_child_node.to_a
            siblings.each_with_index do |sibling, position|
              relationships[key_of(sibling)] = Relationship.new(siblings, position).to_a
            end
          end
        end

        def key_of(node)
          [ node.type, node.source_range.begin_pos, node.source_range.end_pos ]
        end

        class Relationship
          def initialize(siblings, position)
            @siblings = siblings
            @position = position
          end

          def to_a
            [ previous_on_same_line?, following_on_same_line? ]
          end

          private
            attr_reader :siblings, :position

            def previous_on_same_line?
              position.positive? && siblings[position - 1].last_line == siblings[position].first_line
            end

            def following_on_same_line?
              position < siblings.size - 1 && siblings[position].last_line == siblings[position + 1].first_line
            end
        end
    end
end
