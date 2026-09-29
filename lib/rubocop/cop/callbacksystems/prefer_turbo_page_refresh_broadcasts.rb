# Enforces Turbo page refreshes over targeted stream broadcasts.
#
# Targeted broadcasts (append, prepend, replace, remove, and friends) and the
# macros that generate them tie the server to specific partials and DOM targets.
# Page refresh broadcasts let the client morph the current page instead, which
# keeps the broadcasting code declarative and the views as the single source of
# truth.
#
# @example
#   # bad
#   broadcasts_to :board
#   message.broadcast_append_to :messages
#   broadcast_replace_later_to room
#
#   # good - macro
#   broadcasts_refreshes
#   broadcasts_refreshes_to :board
#
#   # good - granular, manual refresh
#   broadcast_refresh_to :board
#   broadcast_refresh_later_to room
#
class RuboCop::Cop::Callbacksystems::PreferTurboPageRefreshBroadcasts < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Prefer Turbo page refreshes over `%<name>s`."

  def on_send(node)
    add_offense(node, message: format(MESSAGE, name: node.method_name)) if targeted_broadcast?(node)
  end

  alias on_csend on_send

  private
    MACROS = %i[ broadcasts broadcasts_to ]
    TARGETED_BROADCAST =
      /\Abroadcast_(append|prepend|replace|update|remove|before|after|action|render)(_later)?(_to)?\z/

    def targeted_broadcast?(node)
      (bare_send?(node) && MACROS.include?(node.method_name)) || TARGETED_BROADCAST.match?(node.method_name)
    end
end
