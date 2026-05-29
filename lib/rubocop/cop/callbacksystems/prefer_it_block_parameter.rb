# Detects single-line brace blocks with a single parameter that should use `it` instead.
#
# In Ruby 4.0+, single-line brace blocks with one parameter can use the implicit
# `it` parameter for more elegant code.
#
# @example
#   # bad
#   items.map { |item| item.name }
#   users.select { |user| user.active? }
#   items.each { |item| process(item) }
#   numbers.map { |n| n.to_s }
#
#   # good
#   items.map { it.name }
#   users.select { it.active? }
#   items.each { process(it) }
#   numbers.map { it.to_s }
#
#   # good - multi-line block
#   items.map do |item|
#     item.name
#   end
#
#   # good - multiple parameters
#   hash.each { |key, value| puts key }
#
class RuboCop::Cop::Callbacksystems::PreferItBlockParameter < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `it` instead of explicit block parameter `|%<param>s|`."

  def on_block(node)
    if single_param_inline_block?(node)
      add_offense(node, message: format(MESSAGE, param: node.first_argument.source)) do |corrector|
        Correction.new(corrector, node).apply
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def single_param_inline_block?(node)
      node.body && node.braces? && node.single_line? && node.arguments.size == 1 && !nested_in_convertible_block?(node)
    end

    def nested_in_convertible_block?(node)
      node.each_ancestor(:any_block).any? { it.arguments.size == 1 && it.braces? && it.single_line? }
    end

    class Correction
      def initialize(corrector, node)
        @corrector = corrector
        @node = node
      end

      def apply
        replace_parameter_references
        remove_arguments
      end

      private
        attr_reader :corrector, :node

        def replace_parameter_references
          node.body.each_node(:lvar).each { corrector.replace(it, "it") if references_parameter?(it) }
          corrector.replace(node.body, "it") if node.body.lvar_type? && references_parameter?(node.body)
        end

        def references_parameter?(lvar_node)
          lvar_node.name.to_s == node.first_argument.source
        end

        def remove_arguments
          corrector.remove(node.arguments.source_range.join(node.arguments.source_range.end.adjust(end_pos: 1)))
        end
    end
end
