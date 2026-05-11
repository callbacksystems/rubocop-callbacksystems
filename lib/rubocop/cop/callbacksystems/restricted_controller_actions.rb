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
    return unless Action.new(node).offense?

    add_offense(node, message: format(MESSAGE, method: node.method_name))
  end

  private
    class Action
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        return false if STANDARD_CONTROLLER_ACTIONS.include?(node.method_name)

        enclosing_class&.then { ControllerClassCheck.new(it, node).offense? }
      end

      private
        def enclosing_class
          node.each_ancestor(:class, :module).first&.then { it.class_type? ? it : nil }
        end

        class ControllerClassCheck
          include RuboCop::Callbacksystems::Helpers

          attr_reader :class_node, :method_node

          def initialize(class_node, method_node)
            @class_node = class_node
            @method_node = method_node
          end

          def offense?
            controller_class? && public_method?
          end

          private
            def controller_class?
              controller_superclass?(class_node.parent_class)
            end

            def public_method?
              method_visibility(method_node) == :public
            end
        end
    end
end
