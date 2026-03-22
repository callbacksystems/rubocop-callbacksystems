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
class RuboCop::Cop::Callbacksystems::RestrictedControllerActions < RuboCop::Cop::Base
  MESSAGE = "Only standard Rails actions (index, show, new, create, edit, update, destroy) are allowed in controllers. Extract `%<method>s` to a new controller."
  ALLOWED_ACTIONS = %i[index show new create edit update destroy].freeze
  CONTROLLER_SUPERCLASSES = RuboCop::Callbacksystems::Helpers::CONTROLLER_SUPERCLASSES

  def on_def(node)
    return unless Action.new(node).offense?

    add_offense(node, message: format(MESSAGE, method: node.method_name))
  end

  private
    class Action
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def offense?
        return false if ALLOWED_ACTIONS.include?(node.method_name)

        class_node = enclosing_class
        class_node && ControllerClassCheck.new(class_node, node).offense?
      end

      private
        def enclosing_class
          node.each_ancestor(:class, :module).first&.then { |n| n.class_type? ? n : nil }
        end

        class ControllerClassCheck
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
              superclass = class_node.parent_class
              superclass && matches_controller_superclass?(superclass)
            end

            def matches_controller_superclass?(superclass)
              name = RuboCop::Callbacksystems::Helpers.constant_name(superclass)
              CONTROLLER_SUPERCLASSES.include?(name) || name&.end_with?("Controller")
            end

            def public_method?
              RuboCop::Callbacksystems::Helpers.method_visibility(method_node) == :public
            end
        end
    end
end
