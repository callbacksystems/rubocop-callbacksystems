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
      hook = Hook.new(node, method_name, processed_source.comments)
      add_offense(node, message: hook.offense_message) { hook.brace(it) } if hook.offense?
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    # A `setup` or `teardown` block, and the one-line form it collapses into.
    class Hook
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, method_name, comments)
        @node = node
        @method_name = method_name
        @comments = comments
      end

      def offense?
        !node.braces? && single_line_body?
      end

      def offense_message
        format(MESSAGE, method: method_name)
      end

      def brace(corrector)
        corrector.replace(node, "#{method_name} { #{node.body.source.strip} }")
        bodies.relocate(corrector)
      end

      private
        attr_reader :node, :method_name, :comments

        def single_line_body?
          node.body&.single_line? && statements_in(node.body).one? && !carries_comment?
        end

        # A brace block is one line, which cannot hold an own-line comment, so a
        # block carrying one keeps the `do ... end` that can.
        def carries_comment?
          holds_comment?(node.source_range, comments)
        end

        # Only a heredoc's marker is inside the block; its body sits below the
        # `end`, so it is written out again under the braced line.
        def bodies
          RuboCop::Callbacksystems::HeredocBodies.new(node)
        end
    end
end
