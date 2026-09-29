# Prohibits files in service object-style directories under `app/`. A service
# is a verb with no noun, so the behavior it holds drifts away from the model
# that owns the data it acts on, and the model is left anemic. The behavior
# belongs to that model, or to a plain object in `app/models` named after the
# concept it stands for.
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
  MESSAGE = "Files in `app/%<directory>s/` are not allowed. Use models or POROs in `app/models/` instead."

  def on_new_investigation
    forbidden_directory&.then { add_offense(offense_range, message: format(MESSAGE, directory: it)) }
  end

  private
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
    ]

    def forbidden_directory
      FORBIDDEN_DIRECTORIES.find { in_directory?(it) }
    end

    def in_directory?(directory)
      processed_source.file_path.match?(%r{(^|/)app/#{Regexp.escape(directory)}/})
    end

    def offense_range
      processed_source.ast || processed_source.buffer.source_range
    end
end
