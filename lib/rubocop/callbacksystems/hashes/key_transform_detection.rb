# The reading PreferStringifyKeys and PreferSymbolizeKeys share: a `transform_keys` that only sends one method to each
# key, given as a block pass or as a block. An including cop names that method as `source_method` and the Active Support
# method saying the same thing as `preferred_method`.
module RuboCop::Callbacksystems::Hashes::KeyTransformDetection
  extend ActiveSupport::Concern

  included do
    extend RuboCop::Cop::AutoCorrector
  end

  def on_send(node)
    report key_transform_of(node)
  end

  alias on_csend on_send

  def on_block(node)
    report key_transform_of(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def key_transform_of(node)
      KeyTransform.new(node, source_method:, preferred_method:, source_comments:)
    end

    class KeyTransform
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Use `%<preferred_method>s` instead of `transform_keys(&:%<source_method>s)`."

      def initialize(node, source_method:, preferred_method:, source_comments:)
        @node = node
        @source_method = source_method
        @preferred_method = preferred_method
        @source_comments = source_comments
      end

      def offense
        if sends_source_method_to_keys?
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: uncommented?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_method, :preferred_method, :source_comments

        def sends_source_method_to_keys?
          transform_keys? && sends_source_method?
        end

        def transform_keys?
          keys_call.method?(:transform_keys) && keys_call.receiver
        end

        def keys_call
          node.call_type? ? node : node.send_node
        end

        def sends_source_method?
          node.call_type? ? passes_source_method? : sends_source_method_to_parameter?
        end

        def passes_source_method?
          keys_call.arguments.one? && block_pass_value&.sym_type? &&
            block_pass_value.value == source_method
        end

        def block_pass_value
          node.first_argument.children.first if node.first_argument.block_pass_type?
        end

        def sends_source_method_to_parameter?
          keys_call.arguments.empty? && single_parameter_block? && exact_source_method_send?
        end

        def single_parameter_block?
          any_block_type?(node) && node.argument_list.one? && block_parameter.arg_type?
        end

        def block_parameter
          node.argument_list.first
        end

        def exact_source_method_send?
          node.body&.send_type? && node.body.method?(source_method) && node.body.arguments.empty? &&
            reads_variable?(node.body.receiver, block_parameter.name)
        end

        def message
          format(MESSAGE, preferred_method: preferred_method, source_method: source_method)
        end

        def uncommented?
          !source_comments.any_within?(node)
        end

        def correct(corrector)
          corrector.replace(node, "#{keys_call.receiver.source}#{call_operator}#{preferred_method}")
        end

        def call_operator
          keys_call.csend_type? ? "&." : "."
        end
    end
end
