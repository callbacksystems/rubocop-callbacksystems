# Detects `hash.transform_keys(&:to_s)` patterns that should use `stringify_keys`.
#
# @example
#   # bad
#   hash.transform_keys(&:to_s)
#   hash.transform_keys { |k| k.to_s }
#
#   # good
#   hash.stringify_keys
#
class RuboCop::Cop::Callbacksystems::PreferStringifyKeys < RuboCop::Cop::Base
  include RuboCop::Callbacksystems::PreferKeyTransform

  private
    def source_method = :to_s

    def preferred_method = :stringify_keys
end
