# Prohibits defining methods directly in ApplicationController.
#
# Methods in ApplicationController should be extracted into concerns
# to keep the base controller clean and maintainable. Include concerns
# instead of defining methods directly.
#
# @example
#   # bad - method defined directly
#   class ApplicationController < ActionController::Base
#     def current_user
#       @current_user ||= User.find(session[:user_id])
#     end
#   end
#
#   # good - use concerns
#   class ApplicationController < ActionController::Base
#     include Authentication
#     include CurrentUser
#   end
#
#   # app/controllers/concerns/current_user.rb
#   module CurrentUser
#     extend ActiveSupport::Concern
#
#     included do
#       helper_method :current_user
#     end
#
#     def current_user
#       @current_user ||= User.find(session[:user_id])
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::ApplicationControllerMethodDefinition < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Don't define methods in ApplicationController. Extract to a concern and include it."

  def on_def(node)
    return unless inside_application_controller?(node)

    add_offense(node, message: MESSAGE)
  end

  alias on_defs on_def

  private
    def inside_application_controller?(node)
      class_node = node.each_ancestor(:class).first
      class_node && application_controller?(class_node)
    end

    def application_controller?(class_node)
      class_name = class_node.identifier
      class_name.const_type? && class_name.children.last == :ApplicationController
    end
end
