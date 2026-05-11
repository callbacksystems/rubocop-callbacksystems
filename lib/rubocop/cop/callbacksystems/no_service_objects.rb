# Prohibits files in service object-style directories under `app/`.
# These patterns (services, decorators, interactors, presenters, forms)
# are not allowed. Use models and POROs in app/models instead.
#
# Only applies to Rails applications (paths under `app/`). Gems or libraries
# that use directories like `commands/` or `queries/` outside of `app/` are
# untouched.
#
# @example
#   # bad - file in app/services/
#   # app/services/order_processor.rb
#
#   # bad - file in app/decorators/
#   # app/decorators/user_decorator.rb
#
#   # bad - file in app/interactors/
#   # app/interactors/create_order.rb
#
#   # bad - file in app/presenters/
#   # app/presenters/user_presenter.rb
#
#   # bad - file in app/forms/
#   # app/forms/registration_form.rb
#
#   # good - use models
#   # app/models/order.rb
#
#   # good - non-Rails gem with commands in lib/
#   # lib/my_gem/commands/run.rb
#
class RuboCop::Cop::Callbacksystems::NoServiceObjects < RuboCop::Cop::Callbacksystems::Base
  FORBIDDEN_DIRECTORIES = %w[
    services
    decorators
    interactors
    presenters
    forms
    operations
    commands
    queries
    use_cases
  ].freeze

  MESSAGE = "Files in `app/%<directory>s/` are not allowed. Use models or POROs in `app/models/` instead."

  def on_new_investigation
    return unless processed_source.file_path && processed_source.ast

    directory = forbidden_directory
    add_offense(processed_source.ast, message: format(MESSAGE, directory: directory)) if directory
  end

  private
    def forbidden_directory
      FORBIDDEN_DIRECTORIES.find { matches_forbidden_path?(it) }
    end

    def matches_forbidden_path?(directory)
      processed_source.file_path.match?(%r{(^|/)app/#{Regexp.escape(directory)}/})
    end
end
