# Prohibits using preload, eager_load, or includes directly in controllers.
# Use a scope in the model instead.
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
class RuboCop::Cop::Callbacksystems::NoDirectEagerLoading < RuboCop::Cop::Base
  EAGER_LOADING_METHODS = %i[preload eager_load includes].freeze
  MESSAGE = "Don't use `%<method>s` directly in controllers. Define a scope in the model instead."

  def on_send(node)
    add_offense(node, message: format(MESSAGE, method: node.method_name)) if offense?(node)
  end

  private
    def offense?(node)
      in_controller? && EAGER_LOADING_METHODS.include?(node.method_name)
    end

    def in_controller?
      path = processed_source.file_path
      path&.include?("/controllers/") || path&.end_with?("_controller.rb")
    end
end
