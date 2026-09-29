# A comment block wrapped to a narrower column than the project uses costs the
# reader extra lines for nothing. When a line breaks mid-sentence and the first
# word of the next line still fits under the Layout/LineLength Max, the block
# is refilled to the full width. A break on a sentence boundary may be
# deliberate, and a block carrying a list, an indented example, a code tail,
# a backtick fence, or an unbreakable word keeps the shape its author gave it.
# A line opening with a label (`Slot 1: ...`) or reading as code is an item of
# its own, so it keeps its line too.
#
# @example
#   # bad - the break falls mid-sentence with room left on the line
#   # A comment that stops
#   # mid-sentence.
#
#   # good - filled to the full width
#   # A comment that stops mid-sentence.
#
#   # good - every break lands on a sentence boundary
#   # First idea ends here.
#   # Second idea starts here.
#
class RuboCop::Cop::Callbacksystems::ReflowComments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    comment_blocks_in(processed_source, reject_tooling_runs: true).each do |comments|
      report ProseBlock.new(comments, max_line_length), rewrites_comments: true
    end
  end

  private
    class ProseBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "This comment breaks mid-sentence with room left on the line. Fill it to %d columns."
      MARKER_WIDTH = "# ".length
      SENTENCE_END = /[.:;!?]["'`)\]]?\z/
      STRUCTURE = /\A(?:\s|[-*|>+@#=]|\d+[.)]|:[a-z][\w-]*:|(?:--|\+\+)\z)/i
      CODE_TAIL = /[{(=]\z/
      LABELED = /\A[A-Za-z][^:\n]{0,30}:\s/
      CODE = /\A[\w.]+(?:\(|\s+[A-Z]\w*::|\s+:\w|\s+["']|\s*=\s)/

      def initialize(comments, max_length)
        @comments = comments
        @max_length = max_length
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(range, message) { correct(it) } if narrow_wrap?
      end

      private
        attr_reader :comments, :max_length

        def narrow_wrap?
          prose? && lines.each_index.any? { absorbs_next?(it) }
        end

        def prose?
          lines.all? { prose_line?(it) }
        end

        def lines
          @lines ||= comments.map { it.text.delete_prefix("#").delete_prefix(" ").rstrip }
        end

        def prose_line?(line)
          !line.match?(STRUCTURE) && !line.match?(CODE_TAIL) && line.exclude?("```") &&
            line.split.all? { width_of(it) <= max_length }
        end

        def width_of(text)
          indent + MARKER_WIDTH + text.length
        end

        def indent
          comments.first.source_range.column
        end

        def absorbs_next?(index)
          continues_at?(index) && width_of("#{lines[index]} #{lines[index + 1].split.first}") <= max_length
        end

        # A line opening with a label or reading as code is an item of its own, not the tail of the sentence above it.
        def continues_at?(index)
          following = lines[index + 1]
          following.present? && !lines[index].empty? && !lines[index].match?(SENTENCE_END) &&
            !following.match?(LABELED) && !following.match?(CODE)
        end

        def range
          range_spanning(comments)
        end

        def message
          format(MESSAGE, max_length)
        end

        def correct(corrector)
          corrector.replace(range, filled_text)
        end

        def filled_text
          paragraphs.flat_map { filled(it) }.join("\n#{" " * indent}")
        end

        def paragraphs
          lines.each_index.slice_when { |index, _| !continues_at?(index) }
            .map { lines.values_at(*it) }
            .flat_map { detached_blank(it) }
            .reject(&:empty?)
        end

        def detached_blank(slice)
          slice.last == "" ? [ slice[0...-1], [ "" ] ] : [ slice ]
        end

        def filled(paragraph)
          words = paragraph.join(" ").split
          words.any? ? wrapped(words).map { "# #{it}" } : [ "#" ]
        end

        def wrapped(words)
          words.each_with_object([]) do |word, filled|
            if filled.any? && width_of("#{filled.last} #{word}") <= max_length
              filled[-1] = "#{filled.last} #{word}"
            else
              filled << word
            end
          end
        end
    end
end
