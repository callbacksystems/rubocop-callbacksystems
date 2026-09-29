# Comments indexed by their position in one source, so asking whether a node contains comments does not walk every
# comment in the file for every node the cops inspect.
class RuboCop::Callbacksystems::Source::Comments
  include RuboCop::Callbacksystems::Helpers

  class << self
    def for(processed_source)
      CACHE_LOCK.synchronize { CACHE[processed_source.comments] ||= new(processed_source.comments) }
    end

    private
      CACHE = ObjectSpace::WeakMap.new
      CACHE_LOCK = Mutex.new
  end

  def initialize(comments)
    @comments = comments.sort_by { it.source_range.begin_pos }
  end

  def any_within?(node_or_range)
    first_within(range_of(node_or_range)).present?
  end

  def tooling_within?(node_or_range)
    within(node_or_range).any? { tooling_comment?(it) }
  end

  def within(node_or_range)
    range = range_of(node_or_range)
    CommentsWithin.new(comments, range, from: first_index_at(range.begin_pos)).to_a
  end

  def own_line_comment_on(line)
    own_line_comments_by_line[line]
  end

  def trailing_comment_on(line)
    trailing_comments_by_line[line]
  end

  def any_on_lines?(lines)
    if lines.begin <= lines.end
      CommentsOnLines.new(comments, lines, from: first_index_on(lines.begin)).any?
    else
      false
    end
  end

  def on_lines(lines)
    if lines.begin <= lines.end
      CommentsOnLines.new(comments, lines, from: first_index_on(lines.begin)).to_a
    else
      []
    end
  end

  private
    attr_reader :comments

    def first_within(range)
      comments[first_index_at(range.begin_pos)]&.then { it if range.contains?(it.source_range) }
    end

    def first_index_at(position)
      begin_positions.bsearch_index { it >= position } || comments.size
    end

    def begin_positions
      @begin_positions ||= comments.map { it.source_range.begin_pos }
    end

    def range_of(node_or_range)
      node_or_range.respond_to?(:source_range) ? node_or_range.source_range : node_or_range
    end

    def own_line_comments_by_line
      @own_line_comments_by_line ||= comments.select { own_line_comment?(it) }.index_by { it.loc.line }
    end

    def trailing_comments_by_line
      @trailing_comments_by_line ||= comments.reject { own_line_comment?(it) }.index_by { it.loc.line }
    end

    def first_index_on(line)
      line_numbers.bsearch_index { it >= line } || comments.size
    end

    def line_numbers
      @line_numbers ||= comments.map { it.loc.line }
    end

    class CommentsWithin
      include Enumerable

      def initialize(comments, range, from:)
        @comments = comments
        @range = range
        @from = from
      end

      def each
        if block_given?
          index = from
          while comments[index] && comments[index].source_range.begin_pos <= range.end_pos
            yield comments[index] if range.contains?(comments[index].source_range)
            index += 1
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :comments, :range, :from
    end

    class CommentsOnLines
      include Enumerable

      def initialize(comments, lines, from:)
        @comments = comments
        @lines = lines
        @from = from
      end

      def each
        if block_given?
          index = from
          while comments[index] && comments[index].loc.line <= lines.end
            yield comments[index]
            index += 1
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :comments, :lines, :from
    end
end
