# Detects `str.strip.gsub(/\s+/, " ")` patterns that should use `squish`. The
# method names the whole transformation, where the chain spells out a regexp
# the reader has to decode.
#
# @example
#   # bad
#   text.strip.gsub(/\s+/, " ")
#   name.strip.gsub(/[[:space:]]+/, " ")
#
#   # good
#   text.squish
#   name.squish
#
class RuboCop::Cop::Callbacksystems::PreferSquish < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = 'Use `squish` instead of `strip.gsub(/\s+/, " ")`.'
  WHITESPACE_PATTERNS = %w[ \s+ [[:space:]]+ ]

  # @!method strip_gsub_pattern(node)
  def_node_matcher :strip_gsub_pattern, <<~PATTERN
    (call $(call _ :strip) :gsub (regexp (str $_pattern) (regopt)) (str " "))
  PATTERN

  def on_send(node)
    strip_gsub_pattern(node) do |strip_call, pattern|
      next if WHITESPACE_PATTERNS.exclude?(pattern)

      add_squish_offense(node, strip_call:)
    end
  end

  alias on_csend on_send

  private
    def add_squish_offense(node, strip_call:)
      if source_comments.any_within?(node)
        add_offense(node, message: MESSAGE)
      else
        add_offense(node, message: MESSAGE) { it.replace(node, replacement_for(strip_call)) }
      end
    end

    def replacement_for(call)
      "#{call_prefix_of(call)}squish"
    end
end
