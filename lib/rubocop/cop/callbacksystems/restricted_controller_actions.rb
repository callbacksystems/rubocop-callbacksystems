# Restricts controller actions to the 7 standard Rails actions.
# Only applies to classes that inherit from ActionController::Base/API.
#
# @example
#   # bad - custom public action
#   class UsersController < ApplicationController
#     def activate
#       # ...
#     end
#   end
#
#   # good - use standard actions
#   class UsersController < ApplicationController
#     def update
#       # ...
#     end
#   end
#
#   # good - create a new controller for the action
#   class Users::ActivationsController < ApplicationController
#     def create
#       # ...
#     end
#   end
#
#   # good - concerns can have any methods
#   module Authentication
#     def current_user
#       # ...
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::RestrictedControllerActions < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Only standard Rails actions (index, show, new, create, edit, update, destroy) are allowed in controllers. Extract `%<method>s` to a new controller."

  def on_def(node)
    action = Action.new(node)
    add_offense(node, message: action.offense_message) if action.offense?
  end

  private
    class Action
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        return false if STANDARD_CONTROLLER_ACTIONS.include?(node.method_name)

        enclosing_controller_class? && public_method?(node)
      end

      def offense_message
        format(MESSAGE, method: node.method_name)
      end

      private
        attr_reader :node

        def enclosing_controller_class?
          enclosing_class&.then { controller_superclass?(it.parent_class) }
        end

        def enclosing_class
          enclosing_class_or_module_of(node)&.then { it if it.class_type? }
        end
    end
end
