# Ensures controller names are plural. A controller stands for the collection
# its routes address, `/users` and `/users/1` alike, so the plural is the name
# Rails derives the route and the resource from, and a singular one reads as a
# model where a reader expects a resource.
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
  def on_class(node)
    report ControllerClass.new(node, ignored_names: cop_config["IgnoredNames"])
  end

  private
    class ControllerClass
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Controller names should be plural. Use `%<plural>sController` instead of `%<singular>sController`."

      def initialize(node, ignored_names:)
        @node = node
        @ignored_names = ignored_names
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node.loc.name, message) if singular?
      end

      private
        attr_reader :node, :ignored_names

        def singular?
          controller_class?(node) && named_controller? && !resource_name.excluded?
        end

        def named_controller?
          class_name.end_with?("Controller")
        end

        def class_name
          constant_name_of(node.identifier)
        end

        def resource_name
          @resource_name ||= ResourceName.new(class_name.delete_suffix("Controller").split("::").last, ignored_names:)
        end

        def message
          format(MESSAGE, plural: resource_name.plural, singular: resource_name)
        end
    end

    class ResourceName
      def initialize(name, ignored_names:)
        @name = name
        @ignored_names = ignored_names
      end

      def excluded?
        ignored? || plural?
      end

      def to_s
        name
      end

      def plural
        name.pluralize
      end

      private
        attr_reader :name, :ignored_names

        def ignored?
          ignored_names.include?(name)
        end

        def plural?
          singular != name || singular.pluralize == name
        end

        def singular
          @singular ||= name.singularize
        end
    end
end
