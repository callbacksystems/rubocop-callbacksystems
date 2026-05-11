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
      next unless plural_name?(name)

      add_offense(node.first_argument, message: format(MESSAGE, singular: name.to_s.singularize, name: name))
    end
  end

  alias on_csend on_send

  private
    def plural_name?(name)
      !name.to_s.start_with?("with_") && name.to_s != name.to_s.singularize
    end
end
