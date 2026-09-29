module RuboCop::Callbacksystems::Helpers::Rails
  EAGER_LOADING_METHODS = %i[ preload eager_load includes ]
  CONTROLLER_SUPERCLASSES = %w[ ApplicationController ActionController::Base ActionController::API ]
  STANDARD_CONTROLLER_ACTIONS = %i[ index show new create edit update destroy ]
  RAILS_TEST_BASE_CLASSES = %w[
    ActiveSupport::TestCase
    ActionDispatch::IntegrationTest
    ActionController::TestCase
    ActionMailer::TestCase
    ActionView::TestCase
    ActiveJob::TestCase
    ActionCable::TestCase
    ActionCable::Channel::TestCase
  ]

  def controller_class?(node)
    node&.class_type? && controller_superclass?(node.parent_class)
  end

  def controller_superclass?(superclass_node)
    name = constant_name_of(superclass_node)&.delete_prefix("::")
    name && (CONTROLLER_SUPERCLASSES.include?(name) || name.end_with?("Controller"))
  end

  def application_controller_class?(node)
    node&.class_type? && node.identifier.short_name == :ApplicationController
  end

  def scope_definition?(node)
    bare_send?(node) && node.method?(:scope) && node.first_argument&.sym_type?
  end

  def rails_test_base_class?(superclass_node)
    RAILS_TEST_BASE_CLASSES.include?(constant_name_of(superclass_node)&.delete_prefix("::"))
  end

  def routes_file?(path)
    path.present? && (path.include?("config/routes") || path.end_with?("routes.rb"))
  end

  def controller_file?(path)
    path.present? && (path.split("/").include?("controllers") || path.end_with?("_controller.rb"))
  end

  def model_file?(path)
    path.present? && path.tr("\\", "/").match?(%r{(?:\A|/)app/models/})
  end

  def test_file?(path)
    path.present? && path.end_with?("_test.rb")
  end
end
