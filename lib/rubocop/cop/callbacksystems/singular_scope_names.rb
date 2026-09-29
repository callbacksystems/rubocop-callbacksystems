# Asks for singular scope names, except under the `with_` prefix. A scope reads
# as an adjective on the relation, `Person.customer` the way `Person.active`
# does, while a plural name restates the collection the relation already is. A
# `with_` scope names what the records carry, and that is plural as often as
# not.
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

  def on_send(node)
    add_offense(node.first_argument, message: message_for(node.first_argument.value)) if plural_scope?(node)
  end

  alias on_csend on_send

  private
    ASSOCIATION_PREFIX = "with_"

    def plural_scope?(node)
      scope_definition?(node) && plural?(node.first_argument.value)
    end

    def plural?(name)
      !name.start_with?(ASSOCIATION_PREFIX) && singular_of(name) != name.to_s
    end

    def singular_of(name)
      name.to_s.singularize
    end

    def message_for(name)
      format(MESSAGE, singular: singular_of(name), name:)
    end
end
