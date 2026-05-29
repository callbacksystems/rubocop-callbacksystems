# ASCII-art section dividers in comments add no information: a row of dashes,
# equals, or box-drawing glyphs is noise to the toolchain and signals padding
# over substance. A pure divider should be removed; a divider wrapping a title
# (`=== Setup ===`) should keep only its inner text as a normal comment.
#
# @example
#   # bad - a pure divider line
#
#   # bad - a title wrapped in dividers
#   # ===== Setup =====
#
#   # good - a plain comment
#   # Setup
#
class RuboCop::Cop::Callbacksystems::NoSectionDividerComments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector
  include RuboCop::Cop::RangeHelp

  PURE_MESSAGE = "Section-divider comments add no information. Remove."
  WRAPPED_MESSAGE = "Strip the divider decorations; keep the inner text as a normal comment."

  # Divider code points: ASCII `-=*_~#`, en/em dash, and the Box Drawing plus
  # Block Elements Unicode blocks. Detected by ordinal so this file stays ASCII.
  DIVIDER_POINTS = Set[0x2D, 0x3D, 0x2A, 0x5F, 0x7E, 0x23, 0x2013, 0x2014].freeze
  DIVIDER_RANGE = (0x2500..0x259F)

  def on_new_investigation
    processed_source.comments.each { report(it) }
  end

  private
    def report(comment)
      divider = DividerComment.new(comment, processed_source)
      add_offense(comment, message: PURE_MESSAGE) { divider.remove(it) } if divider.pure?
      add_offense(comment, message: WRAPPED_MESSAGE) { divider.rewrite(it) } if divider.wrapped?
    end

    # One comment under inspection, with its source context.
    class DividerComment
      include RuboCop::Callbacksystems::Helpers
      include RuboCop::Cop::RangeHelp

      def initialize(comment, processed_source)
        @comment = comment
        @processed_source = processed_source
      end

      def wrapped?
        present? && !pure? && !inner_text.nil?
      end

      def pure?
        present? && only_divider_characters?(trimmed) && divider_run?(trimmed)
      end

      def remove(corrector)
        corrector.remove(removal_range)
      end

      def rewrite(corrector)
        corrector.replace(comment, "# #{inner_text}")
      end

      private
        attr_reader :comment, :processed_source

        def present?
          !trimmed.empty?
        end

        def trimmed
          @trimmed ||= comment.text.delete_prefix("#").strip
        end

        def only_divider_characters?(text)
          text.each_char.all? { divider_or_space?(it) }
        end

        def divider_or_space?(char)
          divider?(char) || char.match?(/\s/)
        end

        def divider?(char)
          DIVIDER_POINTS.include?(char.ord) || DIVIDER_RANGE.cover?(char.ord)
        end

        def divider_run?(text)
          text.each_char.chunk_while { |left, right| divider?(left) && divider?(right) }
            .any? { it.size >= 2 && divider?(it.first) }
        end

        def inner_text
          @inner_text ||= strip_run(trimmed, side: :leading)
            &.then { strip_run(it, side: :trailing) }
            &.then { it unless it.empty? }
        end

        def strip_run(text, side:)
          chars = side == :leading ? text.each_char : text.reverse.each_char
          run = chars.take_while { divider?(it) }
          if run.size >= 2
            side == :leading ? text[run.size..].lstrip : text[0...(text.size - run.size)].rstrip
          end
        end

        def removal_range
          own_line? ? line_removal_range_for(comment) : trailing_removal_range
        end

        def own_line?
          processed_source.lines[comment.loc.line - 1].slice(0, comment.loc.column).strip.empty?
        end

        def trailing_removal_range
          range_with_surrounding_space(range: comment.source_range, side: :left, newlines: false)
        end
    end
end
