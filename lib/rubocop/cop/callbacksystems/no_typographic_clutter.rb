# Keeps typographic characters out of source: smart quotes, en/em dashes,
# ellipses, arrows, bullets, zero-width spaces. They arrive by pasting from
# formatted text or from an AI agent, and they are invisible noise to the
# toolchain, break grep, and signal sloppy review. Decorative line-drawing characters are
# left to a divider-comment cop.
#
# @example
#   # bad - a smart quote, em/en dash, ellipsis, arrow, or bullet in a comment or
#   # string; or a double-hyphen em-dash substitute in a comment
#
#   # good - plain ASCII punctuation
#
class RuboCop::Cop::Callbacksystems::NoTypographicClutter < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Remove typographic character `%<char>s` (U+%<code>s). Use ASCII equivalents."
  DOUBLE_HYPHEN_MESSAGE = "Avoid `--` in comments; use a comma, colon, or parentheses."

  # Written as ordinals so this file stays ASCII-clean under its own cop.
  CLUTTER_POINTS = Set[
    0x00A0, 0x00AB, 0x00AD, 0x00BB, 0x2013, 0x2014, 0x2022, 0x2023, 0x2026,
    0x2039, 0x203A, 0x2043, 0x202F, 0x2060, 0x2212, 0x25E6, 0x2713, 0x2717, 0xFEFF
  ].freeze
  # Clutter ranges: zero-width space/joiner, smart quotes, the arrows block.
  CLUTTER_RANGES = [ 0x200B..0x200D, 0x2018..0x201F, 0x2190..0x21FF ].freeze
  # Only these have one unambiguous ASCII spelling, so only these autocorrect.
  # Written as escapes so this file stays ASCII-clean under its own cop.
  ASCII_EQUIVALENT = {
    "\u2018" => "'", "\u2019" => "'",
    "\u201C" => "\"", "\u201D" => "\"",
    "\u2026" => "...",
    "\u00A0" => " ", "\u202F" => " ",
    "\u200B" => "", "\u200C" => "", "\u200D" => "", "\u2060" => "", "\uFEFF" => "",
    "\u00AD" => ""
  }.freeze

  def on_new_investigation
    processed_source.comments.each do |comment|
      report_clutter(comment, comment.text)
      report_double_hyphen(comment)
    end
    string_nodes.each { report_clutter(it, it.source) }
  end

  private
    def report_clutter(node, text)
      clutter = Clutter.new(node, text)
      add_offense(node, message: clutter.offense_message) { clutter.correct(it) } if clutter.found?
    end

    def report_double_hyphen(comment)
      add_offense(comment, message: DOUBLE_HYPHEN_MESSAGE) if comment.text.include?("--")
    end

    def string_nodes
      processed_source.ast&.each_node(:str) || []
    end

    # The fix runs only when the ASCII form is unambiguous and will not close the
    # string.
    class Clutter
      def initialize(node, text)
        @node = node
        @text = text
      end

      def found?
        !char.nil?
      end

      def offense_message
        format(MESSAGE, char: char, code: code)
      end

      def correct(corrector)
        corrector.replace(node, text.sub(char, replacement)) if replacement && !closes_string?
      end

      private
        attr_reader :node, :text

        def char
          @char ||= text.each_char.find { clutter?(it) }
        end

        def clutter?(character)
          CLUTTER_POINTS.include?(character.ord) || CLUTTER_RANGES.any? { it.cover?(character.ord) }
        end

        def code
          format("%04X", char.ord)
        end

        def replacement
          ASCII_EQUIVALENT[char]
        end

        def closes_string?
          node.respond_to?(:str_type?) && node.str_type? && replacement == node.source.chr
        end
    end
end
