# Detects `hash.transform_keys(&:to_s)` patterns that should use `stringify_keys`.
# The Active Support method names what the keys become, where the transform
# makes the reader work it out from the block.
#
# @example
#   # bad
#   hash.transform_keys(&:to_s)
#   hash.transform_keys { |k| k.to_s }
#
#   # good
#   hash.stringify_keys
#
class RuboCop::Cop::Callbacksystems::PreferStringifyKeys < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::Hashes::KeyTransformDetection

  private
    def source_method
      :to_s
    end

    def preferred_method
      :stringify_keys
    end
end
