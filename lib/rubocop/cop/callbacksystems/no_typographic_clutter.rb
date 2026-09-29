# AI agents (and pasting from formatted text) sneak typographic characters into
# source: smart quotes, dashes, ellipses, invisible spaces. What counts as
# clutter depends on where the character sits.
#
# A comment only describes the code, so a typographic spelling of punctuation is
# noise there: it breaks grep and reads as sloppy review. A string shows the text
# it holds, so a character a reader can see is content someone wrote on purpose.
# Only the invisible marks are clutter inside a string, since those change what
# the string compares as without showing it, so an equality that reads as true
# comes out false and a `split` misses where you meant it to cut.
#
# Arrows, bullets, check marks and guillemets are left alone in both places. They
# carry meaning of their own and no ASCII spelling replaces them.
#
# The characters below are written as escapes, since this file is checked too.
#
# @example
#   # bad - an em dash in a comment
#   # name \u2014 required
#   name = params[:name]
#
#   # bad - a double hyphen (two `-` in a row) standing in for a dash
#   # name \u002D\u002D required
#
#   # bad - a no-break space in a string, which compares unlike a plain space
#   label = "first\u00A0name"
#
#   # good - plain ASCII punctuation in the comment
#   # name, required
#   name = params[:name]
#
#   # good - a visible character left as written inside the string
#   label = "said \u201Cyes\u201D"
#
class RuboCop::Cop::Callbacksystems::NoTypographicClutter < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    prose_comments_in(processed_source).each do |comment|
      report_each Clutter.new(comment.source_range, comment.text, clutter: COMMENT_CLUTTER), rewrites_comments: true
      report_each DoubleHyphens.new(comment), rewrites_comments: true
    end
    string_ranges.each { report_each Clutter.new(it, it.source, clutter: STRING_CLUTTER) }
  end

  private
    # Marks a reader cannot see: no-break space, soft hyphen, narrow no-break space, word joiner, BOM.
    INVISIBLE_POINTS = [ 0x00A0, 0x00AD, 0x202F, 0x2060, 0xFEFF ]
    COMMENT_CLUTTER = Set[*INVISIBLE_POINTS, 0x2013, 0x2014, 0x2026, 0x2212, *0x200B..0x200D, *0x2018..0x201F]
    # Zero-width marks stay out of strings, since they join an emoji sequence and deleting one splits the emoji.
    STRING_CLUTTER = Set[*INVISIBLE_POINTS]

    def string_ranges
      nodes_in(processed_source.ast, :str).map { string_range_of(it) }
    end

    def string_range_of(node)
      node.loc?(:heredoc_body) ? node.loc.heredoc_body : node.source_range
    end

    class Clutter
      def initialize(range, text, clutter:)
        @range = range
        @text = text
        @clutter = clutter
      end

      def each_offense
        occurrences.each { yield it.offense }
      end

      private
        attr_reader :range, :text, :clutter

        def occurrences
          text.each_char.with_index.filter_map do |character, offset|
            Occurrence.new(range, character, offset) if clutter.include?(character.ord)
          end
        end

        class Occurrence
          MESSAGE = "Remove typographic character `%<character>s` (U+%<code_point>s). Use ASCII equivalents."
          # Only characters with one meaning-preserving ASCII spelling, keyed by escape so this file passes its own cop.
          ASCII_EQUIVALENT = {
            "\u2018" => "'", "\u2019" => "'",
            "\u201C" => "\"", "\u201D" => "\"",
            "\u2026" => "...",
            "\u00A0" => " ", "\u202F" => " ",
            "\u200B" => "", "\u200C" => "", "\u200D" => "", "\u2060" => "", "\uFEFF" => "",
            "\u00AD" => ""
          }

          def initialize(source_range, character, offset)
            @source_range = source_range
            @character = character
            @offset = offset
          end

          def offense
            RuboCop::Callbacksystems::Offense.new(range, message, correcting: !replacement.nil?) { correct(it) }
          end

          private
            attr_reader :source_range, :character, :offset

            def range
              source_range.with(begin_pos: source_range.begin_pos + offset, end_pos: range_end)
            end

            def range_end
              source_range.begin_pos + offset + character.length
            end

            def message
              format(MESSAGE, character: character, code_point: code_point)
            end

            def code_point
              format("%04X", character.ord)
            end

            def replacement
              ASCII_EQUIVALENT[character]
            end

            def correct(corrector)
              corrector.replace(range, replacement)
            end
        end
    end

    # Double hyphens standing in for dashes. Which punctuation replaces one depends on the sentence, so there is no fix.
    class DoubleHyphens
      MESSAGE = "Avoid `--` in comments; use a comma, colon, or parentheses."

      def initialize(comment)
        @comment = comment
      end

      def each_offense
        offsets.each { yield RuboCop::Callbacksystems::Offense.new(range_at(it), MESSAGE) }
      end

      private
        attr_reader :comment

        def offsets
          comment.text.enum_for(:scan, /--/).map { Regexp.last_match.begin(0) }
        end

        def range_at(offset)
          comment.source_range.with(begin_pos: comment.source_range.begin_pos + offset, end_pos: range_end(offset))
        end

        def range_end(offset)
          comment.source_range.begin_pos + offset + 2
        end
    end
end
