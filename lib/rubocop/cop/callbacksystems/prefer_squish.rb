# Detects `str.strip.gsub(/\s+/, " ")` patterns that should use `squish`.
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
class RuboCop::Cop::Callbacksystems::PreferSquish < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = 'Use `squish` instead of `strip.gsub(/\s+/, " ")`.'
  WHITESPACE_PATTERNS = %w[\s+ [[:space:]]+].freeze

  # Matches: something.strip.gsub(regexp, " ")
  def_node_matcher :strip_gsub_pattern, <<~PATTERN
    (send (send $_ :strip) :gsub (regexp (str $_pattern) (regopt)) (str " "))
  PATTERN

  def on_send(node)
    strip_gsub_pattern(node) do |receiver, pattern|
      next unless WHITESPACE_PATTERNS.include?(pattern)

      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node.source_range, "#{receiver.source}.squish")
      end
    end
  end
end
