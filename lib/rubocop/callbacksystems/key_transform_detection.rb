# Including cops must define `source_method` (:to_s / :to_sym) and `preferred_method` (:stringify_keys /
# :symbolize_keys).
#
module RuboCop::Callbacksystems::KeyTransformDetection
  extend ActiveSupport::Concern

  included do
    extend RuboCop::Cop::AutoCorrector
  end

  def on_send(node)
    if transform_keys_block_pass?(node)
      add_offense(node, message: message) do |corrector|
        corrector.replace(node, "#{node.receiver.source}.#{preferred_method}")
      end
    end
  end

  alias on_csend on_send

  def on_block(node)
    if transform_keys_block?(node)
      add_offense(node, message: message) do |corrector|
        corrector.replace(node, "#{node.receiver.source}.#{preferred_method}")
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def transform_keys_block_pass?(node)
      node.method?(:transform_keys) &&
        node.receiver &&
        node.arguments.size == 1 &&
        block_pass_symbol_of(node.first_argument) == source_method
    end

    def block_pass_symbol_of(argument)
      symbol = argument.children.first if argument.block_pass_type?
      symbol.value if symbol&.sym_type?
    end

    def message
      "Use `#{preferred_method}` instead of `transform_keys(&:#{source_method})`."
    end

    def transform_keys_block?(node)
      single_arg_transform_keys_block?(node) &&
        body_calls_source_method?(node.body, node.first_argument.name)
    end

    def single_arg_transform_keys_block?(node)
      node.method?(:transform_keys) && node.receiver && node.arguments.size == 1
    end

    def body_calls_source_method?(body, arg_name)
      body&.send_type? &&
        body.receiver&.lvar_type? &&
        body.receiver.children.first == arg_name &&
        body.method?(source_method)
    end
end
