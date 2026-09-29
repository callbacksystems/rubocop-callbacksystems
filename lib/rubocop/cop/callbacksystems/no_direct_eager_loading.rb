# Keeps preload, eager_load, and includes inside app/models. Which associations
# a query loads is knowledge about the model, so every caller asks for a named
# scope instead of repeating that knowledge at each call site.
# Methods defined on a known receiver in the same source are left alone; calls
# on unknown receivers are assumed to use the Active Record query API.
#
# @example
#   # bad - direct eager loading in controller
#   class UsersController < ApplicationController
#     def index
#       @users = User.includes(:posts).all
#     end
#   end
#
#   # good - use a scope
#   class UsersController < ApplicationController
#     def index
#       @users = User.with_posts.all
#     end
#   end
#
#   # In the model:
#   class User < ApplicationRecord
#     scope :with_posts, -> { includes(:posts) }
#   end
#
class RuboCop::Cop::Callbacksystems::NoDirectEagerLoading < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Don't use `%<method>s` outside `app/models`. Define a scope in the model instead."

  def on_new_investigation
    @custom_methods = CustomMethods.new(processed_source.ast)
  end

  def on_send(node)
    add_offense(node, message: format(MESSAGE, method: node.method_name)) if direct_eager_loading?(node)
  end

  alias on_csend on_send

  private
    attr_reader :custom_methods

    def direct_eager_loading?(node)
      !model_file?(processed_source.file_path) && EAGER_LOADING_METHODS.include?(node.method_name) &&
        node.arguments.any? && !custom_methods.defines?(node)
    end

    # Explicit definitions distinguish an application method from the homonymous query API without guessing types.
    class CustomMethods
      include RuboCop::Callbacksystems::Helpers

      def initialize(root)
        @root = root
      end

      def defines?(call)
        if call_on_self?(call)
          siblings.named(call.method_name, beside: call).any?
        elsif call.receiver.const_type?
          singleton_definition_for?(call)
        else
          false
        end
      end

      private
        attr_reader :root

        def siblings
          @siblings ||= RuboCop::Callbacksystems::Methods::Siblings.new
        end

        def singleton_definition_for?(call)
          singleton_definitions.any? do |definition|
            definition.method?(call.method_name) && receiver_names_match?(call.receiver, definition:)
          end
        end

        def singleton_definitions
          @singleton_definitions ||= nodes_in(root, :def, :defs).select do |definition|
            RuboCop::Callbacksystems::Methods::Domain.new(definition).identity == [ :self ] &&
              direct_method_definition?(definition)
          end
        end

        def receiver_names_match?(receiver, definition:)
          enclosing_class_or_module_of(definition).identifier.short_name == receiver.short_name
        end
    end
end
