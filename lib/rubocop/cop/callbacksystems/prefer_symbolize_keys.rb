# Detects `hash.transform_keys(&:to_sym)` patterns that should use `symbolize_keys`.
# The Active Support method names what the keys become, where the transform
# makes the reader work it out from the block.
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
  include RuboCop::Callbacksystems::Hashes::KeyTransformDetection

  private
    def source_method
      :to_sym
    end

    def preferred_method
      :symbolize_keys
    end
end
