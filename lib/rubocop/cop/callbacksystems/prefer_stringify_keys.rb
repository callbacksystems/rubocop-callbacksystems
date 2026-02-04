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
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `stringify_keys` instead of `transform_keys(&:to_s)`."

  # Matches: receiver.transform_keys(&:to_s)
  def_node_matcher :transform_keys_with_to_s_block_pass?, <<~PATTERN
    (send $!nil? :transform_keys (block_pass (sym :to_s)))
  PATTERN

  # Matches: receiver.transform_keys { |k| k.to_s }
  def_node_matcher :transform_keys_with_to_s_block?, <<~PATTERN
    (block (send $!nil? :transform_keys) (args (arg $_arg)) (send (lvar $_body_variable) :to_s))
  PATTERN

  def on_send(node)
    transform_keys_with_to_s_block_pass?(node) do |receiver|
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.stringify_keys")
      end
    end
  end

  def on_block(node)
    transform_keys_with_to_s_block?(node) do |receiver, arg, body_variable|
      next unless arg == body_variable

      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.stringify_keys")
      end
    end
  end
end
