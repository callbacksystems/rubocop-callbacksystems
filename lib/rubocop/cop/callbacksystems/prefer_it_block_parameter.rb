# Detects single-line brace blocks with a single parameter that should use `it`
# instead. Since Ruby 3.4 a block can read its one parameter as `it`, and on a
# single line a name for it only repeats what the receiver already said.
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

  def on_block(node)
    report NamedParameterBlock.new(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class NamedParameterBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Use `it` instead of explicit block parameter `|%<parameter>s|`."
      METHOD_DEFINITIONS = %i[ define_method define_singleton_method ]

      def initialize(node)
        @node = node
      end

      def offense
        offense_for_parameter if convertible?
      end

      private
        attr_reader :node

        def convertible?
          single_line_braced? && single_replaceable_parameter? &&
            !node.lambda_or_proc? && !method_definition? && !nested_in_convertible_block? &&
            !read_inside_an_inner_block? && !it_has_an_existing_meaning?
        end

        def single_line_braced?
          node.body && node.braces? && node.single_line?
        end

        def single_replaceable_parameter?
          node.arguments.size == 1 && node.first_argument.arg_type? && !parameter_reassigned?
        end

        def parameter_reassigned?
          nodes_in(node.body, :lvasgn, :match_var).any? { it.children.first == parameter_name }
        end

        def parameter_name
          node.first_argument.name
        end

        def method_definition?
          METHOD_DEFINITIONS.include?(node.method_name)
        end

        def nested_in_convertible_block?
          node.each_ancestor(:any_block).any? { it.arguments.size == 1 && it.braces? && it.single_line? }
        end

        def read_inside_an_inner_block?
          parameter_reads.any? { |read| read.each_ancestor(*BLOCK_NODE_TYPES).take_while { !it.equal?(node) }.any? }
        end

        def parameter_reads
          @parameter_reads ||= reads_of(parameter_name, within: node.body)
        end

        def it_has_an_existing_meaning?
          parameter_name != :it && (it_variable_nodes.any? || bare_it_calls.any?)
        end

        def it_variable_nodes
          nodes_in(
            node.body,
            :lvar, :lvasgn, :match_var, :shadowarg, :arg, :optarg, :restarg, :kwarg, :kwoptarg, :kwrestarg, :blockarg
          ).select { it.children.first == :it }
        end

        def bare_it_calls
          nodes_in(node.body, :send).select { bare_send?(it) && it.method?(:it) }
        end

        def offense_for_parameter
          if parameter_reads.empty?
            RuboCop::Callbacksystems::Offense.new(node, message)
          else
            RuboCop::Callbacksystems::Offense.new(node, message) { correct(it) }
          end
        end

        def message
          format(MESSAGE, parameter: node.first_argument.source)
        end

        def correct(corrector)
          Correction.new(corrector, node, reads: parameter_reads).apply
        end
    end

    class Correction
      include RuboCop::Callbacksystems::Helpers

      def initialize(corrector, node, reads:)
        @corrector = corrector
        @node = node
        @reads = reads
      end

      def apply
        replace_parameter_reads
        remove_parameters
      end

      private
        attr_reader :corrector, :node, :reads

        def replace_parameter_reads
          reads.each { replace_expression(corrector, it, with: "it") }
        end

        def remove_parameters
          corrector.remove(node.arguments.source_range.join(node.arguments.source_range.end.adjust(end_pos: 1)))
        end
    end
end
