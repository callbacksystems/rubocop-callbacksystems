# Restricts controller actions to the seven standard Rails actions. A custom
# action is a verb bolted onto a controller, so the controllers stop reading the
# same way and routes grow one-off entries. The verb turned into a noun gets a
# controller of its own, `Users::ActivationsController#create`, with the same
# shape as every other one.
#
# Only classes inheriting from a controller are read. A concern is a module,
# and its methods are not actions.
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
  def on_def(node)
    report Action.new(node)
  end

  private
    class Action
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Only standard Rails actions (index, show, new, create, edit, update, destroy) are allowed in " \
        "controllers. Extract `%<method>s` to a new controller."

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if restricted?
      end

      private
        attr_reader :node

        def restricted?
          custom? && direct_method_definition?(node) && instance_method? && in_restricted_controller? &&
            public_method?(node)
        end

        def custom?
          STANDARD_CONTROLLER_ACTIONS.exclude?(node.method_name)
        end

        def instance_method?
          RuboCop::Callbacksystems::Methods::Domain.new(node).scope == :instance
        end

        def in_restricted_controller?
          enclosing_class_or_module_of(node).then do |controller|
            controller_class?(controller) && !application_controller_class?(controller)
          end
        end

        def message
          format(MESSAGE, method: node.method_name)
        end
    end
end
