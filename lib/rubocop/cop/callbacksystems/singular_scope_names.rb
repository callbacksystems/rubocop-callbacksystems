# Ensures scope names are singular (unless they use `with_*` prefix).
#
# @example
#   # bad - plural scope name
#   scope :customers, -> { where(customer: true) }
#   scope :admins, -> { where(role: :admin) }
#
#   # good - singular scope name
#   scope :customer, -> { where(customer: true) }
#   scope :admin, -> { where(role: :admin) }
#
#   # good - with_* prefix can be plural (for associations)
#   scope :with_posts, -> { includes(:posts) }
#   scope :with_comments, -> { preload(:comments) }
#
class RuboCop::Cop::Callbacksystems::SingularScopeNames < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Scope names should be singular. Use `%<singular>s` instead of `%<name>s`."

  # @!method scope_with_symbol_name?(node)
  def_node_matcher :scope_with_symbol_name?, <<~PATTERN
    (send nil? :scope (sym $_name) ...)
  PATTERN

  def on_send(node)
    scope_with_symbol_name?(node) do |name|
      string_name = name.to_s
      singular = string_name.singularize

      add_offense(node.first_argument, message: format(MESSAGE, singular:, name:)) unless string_name.start_with?("with_") || string_name == singular
    end
  end

  alias on_csend on_send
end
