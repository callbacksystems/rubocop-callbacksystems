# A `validate` declaration already says what the callback does. Its name should
# describe the condition it checks, so the declaration reads as a sentence.
# Renaming needs an understanding of that condition and every caller, so this
# cop reports the registration without changing the callback or its definition.
#
# @example
#   # bad
#   validate :validate_email
#   validate :valid_membership
#
#   # good
#   validate :ensure_deliverable_email
#   validate :no_expired_membership
#   validate :expiration_date_cannot_be_in_the_past
#
class RuboCop::Cop::Callbacksystems::NoRedundantValidationName < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Validation callback `%<name>s` repeats `validate`. Name the condition instead, like `ensure_*` or `no_*`."

  def on_send(node)
    if validation_registration?(node)
      node.arguments.each do |argument|
        add_offense(argument, message: format(MESSAGE, name: argument.value)) if redundant_name?(argument)
      end
    end
  end

  alias on_csend on_send

  private
    def validation_registration?(node)
      node.method?(:validate) && call_on_self?(node) && !enclosing_method_of(node)
    end

    def redundant_name?(argument)
      argument.sym_type? && argument.value.match?(/\A(?:valid|validate)(?:_|[!?]?\z)/)
    end
end
