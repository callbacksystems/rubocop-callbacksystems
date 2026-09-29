# ASCII-art section dividers in comments add no information: a row of dashes,
# equals, or box-drawing glyphs is noise to the toolchain and signals padding
# over substance. A pure divider should be removed; a divider wrapping a title
# (`=== Setup ===`) should keep only its inner text as a normal comment.
#
# @example
#   # bad - a pure divider, here closing the statement it follows
#   configure_defaults # ==========
#
#   # bad - a title wrapped in dividers
#   # ===== Setup =====
#
#   # good - a plain comment
#   # Setup
#
class RuboCop::Cop::Callbacksystems::NoSectionDividerComments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    processed_source.comments.each { report DividerComment.new(it), rewrites_comments: true }
  end

  private
    class DividerComment
      include RuboCop::Callbacksystems::Helpers

      PURE_MESSAGE = "Section-divider comments add no information. Remove."
      WRAPPED_MESSAGE = "Strip the divider decorations; keep the inner text as a normal comment."
      # `-=*_~#`, the dashes, and the Box Drawing and Block Elements blocks, by ordinal so this file stays ASCII.
      DIVIDER_POINTS = Set[0x2D, 0x3D, 0x2A, 0x5F, 0x7E, 0x23, 0x2013, 0x2014]
      DIVIDER_RANGE = (0x2500..0x259F)

      def initialize(comment)
        @comment = comment
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(comment, message) { correct(it) } if divider_comment?
      end

      private
        attr_reader :comment

        def divider_comment?
          !tooling_comment?(comment) && (pure? || wrapped?)
        end

        def pure?
          present? && only_divider_characters?(trimmed) && divider_run?(trimmed)
        end

        def present?
          !trimmed.empty?
        end

        def trimmed
          @trimmed ||= comment.text.delete_prefix("#").strip
        end

        def only_divider_characters?(text)
          text.each_char.all? { divider_or_space?(it) }
        end

        def divider_or_space?(character)
          divider?(character) || character.match?(/\s/)
        end

        def divider?(character)
          DIVIDER_POINTS.include?(character.ord) || DIVIDER_RANGE.cover?(character.ord)
        end

        def divider_run?(text)
          text.each_char.chunk_while { |left, right| divider?(left) && divider?(right) }
            .any? { it.size >= 2 && divider?(it.first) }
        end

        def wrapped?
          present? && !inner_text.nil?
        end

        def inner_text
          @inner_text ||= strip_run(trimmed, side: :leading)&.then { strip_run(it, side: :trailing) }
        end

        def strip_run(text, side:)
          characters = side == :leading ? text.each_char : text.reverse.each_char
          run = characters.take_while { divider?(it) }
          if run.size >= 2
            side == :leading ? text[run.size..].lstrip : text[0...(text.size - run.size)].rstrip
          end
        end

        def message
          pure? ? PURE_MESSAGE : WRAPPED_MESSAGE
        end

        def correct(corrector)
          if pure?
            corrector.remove(comment_removal_range_for(comment))
          else
            corrector.replace(comment, "# #{inner_text}")
          end
        end
    end
end
