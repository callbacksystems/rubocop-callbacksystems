# Detects single-line brace blocks with a single parameter that should use `it` instead.
#
# In Ruby 4.0+, single-line brace blocks with one parameter can use the implicit `it` parameter for more elegant code.
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
#   # good - lambda or proc, where the parameter name documents the signature
#   double = ->(number) { number * 2 }
#   greet = proc { |name| puts name }
#
#   # good - define_method, where the block sets the defined method's signature
#   define_method(:double) { |number| number * 2 }
#
class RuboCop::Cop::Callbacksystems::PreferItBlockParameter < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `it` instead of explicit block parameter `|%<param>s|`."

  def on_block(node)
    candidate = Candidate.new(node)
    if candidate.convertible?
      add_offense(node, message: format(MESSAGE, param: node.first_argument.source)) do |corrector|
        Correction.new(corrector, candidate).apply
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class Candidate
      METHOD_DEFINITIONS = %i[define_method define_singleton_method].freeze

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def convertible?
        single_line_braced? && single_replaceable_parameter? && !node.lambda_or_proc? &&
          !method_definition? && !nested_in_convertible_block? && !captured_by_nested_block?
      end

      def references_parameter?(lvar_node)
        lvar_node.name.to_s == node.first_argument.source
      end

      private
        def single_line_braced?
          node.body && node.braces? && node.single_line?
        end

        def single_replaceable_parameter?
          node.arguments.size == 1 && node.first_argument.arg_type?
        end

        def method_definition?
          METHOD_DEFINITIONS.include?(node.method_name)
        end

        def nested_in_convertible_block?
          node.each_ancestor(:any_block).any? { it.arguments.size == 1 && it.braces? && it.single_line? }
        end

        # Inside another block `it` is that block's own parameter, so rewriting would rebind it silently.
        def captured_by_nested_block?
          node.body.each_node(:lvar).any? { captured?(it) }
        end

        def captured?(lvar_node)
          references_parameter?(lvar_node) && lvar_node.each_ancestor(:any_block).first != node
        end
    end

    class Correction
      def initialize(corrector, candidate)
        @corrector = corrector
        @candidate = candidate
      end

      def apply
        replace_parameter_references
        remove_arguments
      end

      private
        attr_reader :corrector, :candidate
        delegate :node, :references_parameter?, to: :candidate, private: true

        def replace_parameter_references
          node.body.each_node(:lvar).each { corrector.replace(it, "it") if references_parameter?(it) }
          corrector.replace(node.body, "it") if node.body.lvar_type? && references_parameter?(node.body)
        end

        def remove_arguments
          corrector.remove(node.arguments.source_range.join(node.arguments.source_range.end.adjust(end_pos: 1)))
        end
    end
end
