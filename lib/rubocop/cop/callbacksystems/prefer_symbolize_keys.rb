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
class RuboCop::Cop::Callbacksystems::PreferSymbolizeKeys < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `symbolize_keys` instead of `transform_keys(&:to_sym)`."

  # Matches: receiver.transform_keys(&:to_sym)
  def_node_matcher :transform_keys_with_to_sym_block_pass?, <<~PATTERN
    (send $!nil? :transform_keys (block_pass (sym :to_sym)))
  PATTERN

  # Matches: receiver.transform_keys { |k| k.to_sym }
  def_node_matcher :transform_keys_with_to_sym_block?, <<~PATTERN
    (block (send $!nil? :transform_keys) (args (arg $_arg)) (send (lvar $_body_variable) :to_sym))
  PATTERN

  def on_send(node)
    transform_keys_with_to_sym_block_pass?(node) do |receiver|
      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.symbolize_keys")
      end
    end
  end

  def on_block(node)
    transform_keys_with_to_sym_block?(node) do |receiver, arg, body_variable|
      next unless arg == body_variable

      add_offense(node, message: MESSAGE) do |corrector|
        corrector.replace(node, "#{receiver.source}.symbolize_keys")
      end
    end
  end
end
