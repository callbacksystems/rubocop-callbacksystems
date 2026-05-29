# Enforces the use of `{ }` instead of `do end` for single-line setup and teardown blocks.
#
# @example
#   # bad
#   setup do
#     @user = users(:bruno)
#   end
#
#   # good
#   setup { @user = users(:bruno) }
#
#   # good (multi-line is fine with do/end)
#   setup do
#     @user = users(:bruno)
#     @account = accounts(:callback)
#   end
#
class RuboCop::Cop::Callbacksystems::SingleLineSetupBlock < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `%<method>s { ... }` for single-line blocks instead of `do ... end`."

  # @!method setup_or_teardown_block?(node)
  def_node_matcher :setup_or_teardown_block?, <<~PATTERN
    (block (send nil? ${:setup :teardown}) ...)
  PATTERN

  def on_block(node)
    setup_or_teardown_block?(node) do |method_name|
      next if node.braces? || !single_line_body?(node)

      add_offense(node, message: format(MESSAGE, method: method_name)) do |corrector|
        corrector.replace(node, "#{method_name} { #{node.body.source.strip} }")
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def single_line_body?(node)
      node.body&.single_line? && statements_in(node.body).one?
    end
end
