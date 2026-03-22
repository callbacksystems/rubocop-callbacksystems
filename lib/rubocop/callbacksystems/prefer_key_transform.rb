# Shared behavior for cops that prefer `stringify_keys` / `symbolize_keys`
# over `transform_keys(&:to_s)` / `transform_keys(&:to_sym)`.
#
# Including classes must define:
#   - `source_method`    — e.g. `:to_s` or `:to_sym`
#   - `preferred_method` — e.g. `:stringify_keys` or `:symbolize_keys`
#
module RuboCop::Callbacksystems::PreferKeyTransform
  def self.included(base)
    base.extend(RuboCop::Cop::AutoCorrector)
  end

  def on_send(node)
    return unless transform_keys_block_pass?(node)

    add_offense(node, message: message) do |corrector|
      corrector.replace(node, "#{node.receiver.source}.#{preferred_method}")
    end
  end

  def on_block(node)
    return unless transform_keys_block?(node)

    add_offense(node, message: message) do |corrector|
      corrector.replace(node, "#{node.send_node.receiver.source}.#{preferred_method}")
    end
  end

  private
    def transform_keys_block_pass?(node)
      node.method_name == :transform_keys &&
        node.receiver &&
        node.arguments.size == 1 &&
        node.arguments.first.block_pass_type? &&
        node.arguments.first.children.first&.sym_type? &&
        node.arguments.first.children.first.value == source_method
    end

    def transform_keys_block?(node)
      return false unless single_arg_transform_keys_block?(node)

      body_calls_source_method?(node.body, node.arguments.first.name)
    end

    def single_arg_transform_keys_block?(node)
      node.method?(:transform_keys) && node.send_node.receiver && node.arguments.size == 1
    end

    def body_calls_source_method?(body, arg_name)
      body&.send_type? &&
        body.receiver&.lvar_type? &&
        body.receiver.children.first == arg_name &&
        body.method_name == source_method
    end

    def message
      "Use `#{preferred_method}` instead of `transform_keys(&:#{source_method})`."
    end
end
