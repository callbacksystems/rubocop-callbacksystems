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
class RuboCop::Cop::Callbacksystems::PreferSquish < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = 'Use `squish` instead of `strip.gsub(/\s+/, " ")`.'
  WHITESPACE_PATTERNS = %w[\s+ [[:space:]]+].freeze

  # @!method strip_gsub_pattern(node)
  def_node_matcher :strip_gsub_pattern, <<~PATTERN
    (send (call $_ :strip) :gsub (regexp (str $_pattern) (regopt)) (str " "))
  PATTERN

  def on_send(node)
    strip_gsub_pattern(node) do |receiver, pattern|
      next if WHITESPACE_PATTERNS.exclude?(pattern)

      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.squish")
      end
    end
  end

  alias on_csend on_send
end
