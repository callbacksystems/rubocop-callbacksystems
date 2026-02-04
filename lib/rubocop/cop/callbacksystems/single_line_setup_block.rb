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
class RuboCop::Cop::Callbacksystems::SingleLineSetupBlock < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `%<method>s { ... }` for single-line blocks instead of `do ... end`."

  # Matches: setup do ... end or teardown do ... end
  def_node_matcher :setup_or_teardown_block?, <<~PATTERN
    (block (send nil? ${:setup :teardown}) ...)
  PATTERN

  def on_block(node)
    setup_or_teardown_block?(node) do |method_name|
      next if node.braces?
      next unless single_line_body?(node)

      add_offense(node, message: format(MESSAGE, method: method_name)) do |corrector|
        body_source = node.body.source.strip
        corrector.replace(node, "#{method_name} { #{body_source} }")
      end
    end
  end

  private
    def single_line_body?(node)
      node.body &&
        !(node.body.begin_type? && node.body.children.many?) &&
        node.body.first_line == node.body.last_line
    end
end
