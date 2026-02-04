# Prohibits files in service object-style directories.
# These patterns (services, decorators, interactors, presenters, forms)
# are not allowed. Use models and POROs in app/models instead.
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
class RuboCop::Cop::Callbacksystems::NoServiceObjects < RuboCop::Cop::Base
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

  MESSAGE = "Files in `%<directory>s/` are not allowed. Use models or POROs in `app/models/` instead."

  def on_new_investigation
    return unless processed_source.file_path && processed_source.ast

    directory = forbidden_directory
    add_offense(processed_source.ast, message: format(MESSAGE, directory: directory)) if directory
  end

  private
    def forbidden_directory
      FORBIDDEN_DIRECTORIES.find { |directory| matches_forbidden_path?(directory) }
    end

    def matches_forbidden_path?(directory)
      processed_source.file_path.include?("/#{directory}/") || processed_source.file_path.include?("/app/#{directory}/")
    end
end
