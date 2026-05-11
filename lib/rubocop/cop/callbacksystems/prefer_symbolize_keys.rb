# Detects `hash.transform_keys(&:to_sym)` patterns that should use `symbolize_keys`.
#
# @example
#   # bad
#   hash.transform_keys(&:to_sym)
#   hash.transform_keys { |k| k.to_sym }
#
#   # good
#   hash.symbolize_keys
#
class RuboCop::Cop::Callbacksystems::PreferSymbolizeKeys < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::KeyTransformDetection

  private
    def source_method = :to_sym

    def preferred_method = :symbolize_keys
end
