# The edits of a rehearsed correction with the comments they swallowed written back in: trailing the rewritten line they
# were on, or standing on lines of their own where the code around them went away.
class RuboCop::Callbacksystems::Autocorrection::CommentRescue
  def initialize(rehearsal, processed_source)
    @rehearsal = rehearsal
    @processed_source = processed_source
  end

  def preserving(original_correction)
    replacements.none?(&:rescues?) ? original_correction : correction
  end

  def correction
    if replacements.any?(&:rescues?) && replacements.none?(&:rescues_tooling?)
      ->(corrector) { replacements.each { corrector.replace(it.range, it.rescued_text) } }
    end
  end

  private
    attr_reader :rehearsal, :processed_source

    def replacements
      @replacements ||= rehearsal.as_replacements.map do |range, text|
        Replacement.new(range, text, source_comments)
      end
    end

    def source_comments
      @source_comments ||= RuboCop::Callbacksystems::Source::Comments.for(processed_source)
    end

    class Replacement
      include RuboCop::Callbacksystems::Helpers

      attr_reader :range

      def initialize(range, text, source_comments)
        @range = range
        @text = text
        @source_comments = source_comments
      end

      def rescues?
        comments.any?
      end

      def rescues_tooling?
        comments.any? { tooling_comment?(it) }
      end

      def rescued_text
        if comments.empty? then text
        elsif text.empty? then standing_lines
        else trailing_text
        end
      end

      private
        attr_reader :text, :source_comments

        def comments
          @comments ||= source_comments.within(range).reject { text.include?(it.text) }
        end

        def standing_lines
          comments.map.with_index { |comment, index| index.zero? ? opening_line_for(comment) : own_line_for(comment) }
            .join + closing
        end

        def opening_line_for(comment)
          before = range.begin.source_line[0...range.begin.column]
          if before.strip.present? then " #{comment.text}"
          elsif range.begin.column.zero? then own_line_for(comment).delete_prefix("\n")
          else comment.text
          end
        end

        def own_line_for(comment)
          "\n#{line_indentation_of(comment)}#{comment.text}"
        end

        # A comment that trailed code takes the indentation of its line, not the column it sat at.
        def line_indentation_of(comment)
          comment.source_range.source_line[/\A[ \t]*/]
        end

        def closing
          after = range.end.source_line[range.end.column..]
          after.strip.empty? ? "" : "\n#{" " * range.end.column}"
        end

        def trailing_text
          "#{opened(text.chomp)}#{trailing_below_first}#{standing}#{"\n" if text.end_with?("\n")}"
        end

        def opened(body)
          body.sub(/$/) { on_first_line.map { " #{it.text}" }.join }
        end

        def on_first_line
          comments.select { it.loc.line == range.line && !own_line_comment?(it) }
        end

        def trailing_below_first
          comments.reject { it.loc.line == range.line || own_line_comment?(it) }.map { " #{it.text}" }.join
        end

        def standing
          comments.select { own_line_comment?(it) }.map { own_line_for(it) }.join
        end
    end
end
