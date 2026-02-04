require "test_helper"

class RuboCop::Cop::Callbacksystems::ApplicationControllerMethodDefinitionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ApplicationControllerMethodDefinition

  test "registers offense for method in ApplicationController" do
    assert_offense <<~RUBY
      class ApplicationController < ActionController::Base
        def current_user
        end
      end
    RUBY
  end

  test "registers offense for private method in ApplicationController" do
    assert_offense <<~RUBY
      class ApplicationController < ActionController::Base
        private

        def set_locale
        end
      end
    RUBY
  end

  test "registers offense for class method in ApplicationController" do
    assert_offense <<~RUBY
      class ApplicationController < ActionController::Base
        def self.helper_method
        end
      end
    RUBY
  end

  test "allows includes in ApplicationController" do
    assert_no_offense <<~RUBY
      class ApplicationController < ActionController::Base
        include Authentication
        include CurrentLocale
      end
    RUBY
  end

  test "allows before_action in ApplicationController" do
    assert_no_offense <<~RUBY
      class ApplicationController < ActionController::Base
        before_action :authenticate_user
      end
    RUBY
  end

  test "allows methods in other controllers" do
    assert_no_offense <<~RUBY
      class UsersController < ApplicationController
        def index
        end
      end
    RUBY
  end

  test "allows methods in concerns" do
    assert_no_offense <<~RUBY
      module Authentication
        extend ActiveSupport::Concern

        def current_user
        end
      end
    RUBY
  end

  test "allows methods in namespaced ApplicationController" do
    assert_no_offense <<~RUBY
      class Admin::BaseController < ApplicationController
        def admin_user
        end
      end
    RUBY
  end
end
