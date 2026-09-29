require "test_helper"

class ResultCacheIntegrationTest < ActiveSupport::TestCase
  include TemporaryProject

  setup { create_configuration }

  test "cache follows the test source read by PublicMethodsMustHaveTests" do
    create_file "example.gemspec", gemspec_source
    source = create_file "lib/widget.rb", widget_source

    first_output, first_error, first_status = inspect(source, with: "Callbacksystems/PublicMethodsMustHaveTests")
    create_file "test/widget_test.rb", "test \"render returns the widget\" do\nend\n"
    second_output, second_error, second_status = inspect(source, with: "Callbacksystems/PublicMethodsMustHaveTests")

    assert_not_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_predicate second_status, :success?, "#{second_output}\n#{second_error}"
  end

  test "cache follows whether a lib project has a gemspec" do
    source = create_file "lib/widget.rb", widget_source

    first_output, first_error, first_status = inspect(source, with: "Callbacksystems/PublicMethodsMustHaveTests")
    create_file "example.gemspec", gemspec_source
    second_output, second_error, second_status = inspect(source, with: "Callbacksystems/PublicMethodsMustHaveTests")

    assert_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_not_predicate second_status, :success?, "#{second_output}\n#{second_error}"
  end

  test "cache follows fixture files used to identify fixture accessors" do
    source = create_file "test/models/widget_test.rb", <<~RUBY
      test "reads the widget" do
        widget = widgets(:one)
        assert widget
      end
    RUBY

    first_output, first_error, first_status = inspect(source, with: "Callbacksystems/SingleUseFixtureVariable")
    create_file "test/fixtures/widgets.yml", "one:\n  name: Example\n"
    second_output, second_error, second_status = inspect(source, with: "Callbacksystems/SingleUseFixtureVariable")

    assert_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_not_predicate second_status, :success?, "#{second_output}\n#{second_error}"
  end

  test "cache follows production source used to order tests" do
    source = create_file "test/models/widget_test.rb", <<~RUBY
      test "name reads the name" do
      end

      test "render returns the widget" do
      end
    RUBY
    create_file "app/models/widget.rb", <<~RUBY
      class Widget
        def render; end
        def name; end
      end
    RUBY

    first_output, first_error, first_status = inspect(source, with: "Callbacksystems/TestMethodOrder")
    create_file "app/models/widget.rb", <<~RUBY
      class Widget
        def name; end
        def render; end
      end
    RUBY
    second_output, second_error, second_status = inspect(source, with: "Callbacksystems/TestMethodOrder")

    assert_not_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_predicate second_status, :success?, "#{second_output}\n#{second_error}"
  end

  test "cache follows inherited default scopes used to name eager loading scopes" do
    create_file "app/models/application_record.rb", "class ApplicationRecord < ActiveRecord::Base; end"
    source = create_file "app/models/user.rb", <<~RUBY
      class User < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY

    first_output, first_error, first_status = inspect(source, with: "Callbacksystems/EagerLoadingScopeNaming")
    create_file "app/models/application_record.rb", <<~RUBY
      class ApplicationRecord < ActiveRecord::Base
        default_scope { includes(:posts) }
      end
    RUBY
    second_output, second_error, second_status = inspect(source, with: "Callbacksystems/EagerLoadingScopeNaming")

    assert_not_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_includes first_output, "Reserve with_* for eager loading scopes."
    assert_predicate second_status, :success?, "#{second_output}\n#{second_error}"
  end

  private
    def create_configuration
      create_file ".rubocop.yml", <<~YAML
        plugins:
          - rubocop-callbacksystems

        AllCops:
          NewCops: enable
          SuggestExtensions: false
      YAML
    end

    def gemspec_source
      <<~RUBY
        Gem::Specification.new do |spec|
          spec.required_ruby_version = ">= 4.0"
        end
      RUBY
    end

    def widget_source
      <<~RUBY
        class Widget
          def render
            build_widget
          end
        end
      RUBY
    end

    def inspect(source, with:)
      RuboCopCommand.new(project).run \
        "--config", project.path_of(".rubocop.yml"),
        "--only", with,
        "--cache", "true",
        "--cache-root", project.path_of("cache"),
        "--format", "simple",
        source
    end
end
