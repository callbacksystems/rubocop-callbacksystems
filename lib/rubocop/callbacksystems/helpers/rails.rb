module RuboCop::Callbacksystems::Helpers::Rails
  EAGER_LOADING_METHODS = %i[preload eager_load includes].freeze
  CONTROLLER_SUPERCLASSES = %w[ApplicationController ActionController::Base ActionController::API].freeze
  STANDARD_CONTROLLER_ACTIONS = %i[index show new create edit update destroy].freeze
  RAILS_TEST_BASE_CLASSES = %w[
    ActiveSupport::TestCase
    ActionDispatch::IntegrationTest
    ActionController::TestCase
    ActionMailer::TestCase
    ActionView::TestCase
    ActiveJob::TestCase
    ActionCable::TestCase
    ActionCable::Channel::TestCase
  ].freeze

  def controller_superclass?(superclass_node)
    name = constant_name_of(superclass_node)
    name && (CONTROLLER_SUPERCLASSES.include?(name) || name.end_with?("Controller"))
  end

  def rails_test_base_class?(superclass_node)
    RAILS_TEST_BASE_CLASSES.include?(constant_name_of(superclass_node))
  end

  def routes_file?(path)
    path.present? && (path.include?("config/routes") || path.end_with?("routes.rb"))
  end
end
