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
class RuboCop::Cop::Callbacksystems::SingularScopeNames < RuboCop::Cop::Base
  # Matches: scope :name, -> { ... }
  def_node_matcher :scope_with_symbol_name?, <<~PATTERN
    (send nil? :scope (sym $_name) ...)
  PATTERN

  def on_send(node)
    scope_with_symbol_name?(node) do |name|
      name_string = name.to_s
      next if name_string.start_with?("with_")
      next if name_string == name_string.singularize

      add_offense(node.arguments.first, message: "Scope names should be singular. Use `#{name_string.singularize}` instead of `#{name_string}`.")
    end
  end
end
