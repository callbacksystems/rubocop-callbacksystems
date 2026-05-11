# Forbids multiple classes or modules at the top level of a file.
# Each file should contain only one top-level class or module.
#
# This enforces the convention that each file defines a single
# namespace, making code organization clearer and more predictable.
#
# @example
#   # bad - multiple top-level classes
#   class User
#   end
#
#   class Admin
#   end
#
#   # bad - multiple top-level modules
#   module Authentication
#   end
#
#   module Authorization
#   end
#
#   # bad - mixed top-level class and module
#   class User
#   end
#
#   module UserHelpers
#   end
#
#   # good - single top-level class
#   class User
#   end
#
#   # good - single top-level module
#   module Authentication
#   end
#
#   # good - nested classes/modules inside one top-level
#   class User
#     class Profile
#     end
#
#     module Validations
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::SingleTopLevelClassOrModule < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Only one top-level class or module is allowed per file."

  def on_new_investigation
    top_level_definitions.drop(1).each do |node|
      add_offense(node, message: MESSAGE)
    end
  end

  private
    def top_level_definitions
      return [] unless processed_source.ast

      definitions_from(processed_source.ast)
    end

    def definitions_from(node)
      case node.type
      when :class, :module then [ node ]
      when :begin then node.children.select { class_or_module?(it) }
      else []
      end
    end

    def class_or_module?(node)
      node&.type?(:class, :module)
    end
end
