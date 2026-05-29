# Ensures controller names are plural.
#
# @example
#   # bad
#   class UserController < ApplicationController
#   end
#
#   # good
#   class UsersController < ApplicationController
#   end
#
#   # good - already plural
#   class PeopleController < ApplicationController
#   end
#
#   # good - ignored names (configurable)
#   class ApplicationController < ActionController::Base
#   end
#
#   class BaseController < ApplicationController
#   end
#
class RuboCop::Cop::Callbacksystems::PluralControllerNames < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Controller names should be plural. Use `%<plural>sController` instead of `%<singular>sController`."

  def on_class(node)
    controller = ControllerClass.new(node, cop_config)
    add_offense(node.loc.name, message: controller.offense_message) if controller.offense?
  end

  private
    class ControllerClass
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, cop_config)
        @node = node
        @cop_config = cop_config
      end

      def offense?
        singular_resource_name
      end

      def offense_message
        format(MESSAGE, plural: singular_resource_name.pluralize, singular: singular_resource_name)
      end

      private
        attr_reader :node, :cop_config

        def singular_resource_name
          @singular_resource_name ||= non_plural_non_ignored_resource if controller_class? && named_controller?
        end

        def controller_class?
          controller_superclass?(node.parent_class)
        end

        def named_controller?
          class_name&.end_with?("Controller")
        end

        def class_name
          constant_name_of(node.identifier)
        end

        def non_plural_non_ignored_resource
          resource_name unless Resource.new(resource_name, cop_config).excluded?
        end

        def resource_name
          class_name.delete_suffix("Controller").split("::").last
        end
    end

    class Resource
      def initialize(resource, cop_config)
        @resource = resource
        @cop_config = cop_config
      end

      def excluded?
        ignored? || plural?
      end

      private
        attr_reader :resource, :cop_config

        def ignored?
          ignored_names.include?(resource)
        end

        def ignored_names
          cop_config["IgnoredNames"]
        end

        def plural?
          singularized = resource.singularize
          singularized != resource || singularized.pluralize == resource
        end
    end
end
