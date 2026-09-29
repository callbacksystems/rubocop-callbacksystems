require "test_helper"

class ProjectIndexIntegrationTest < ActiveSupport::TestCase
  include TemporaryProject

  test "plugin configuration gives RuboCop a project index" do
    assert_project_index_with <<~YAML
      plugins:
        - rubocop-callbacksystems

      AllCops:
        NewCops: enable
    YAML
  end

  test "inherited style gives RuboCop a project index" do
    assert_project_index_with <<~YAML
      inherit_gem:
        rubocop-callbacksystems: rubocop.yml
    YAML
  end

  private
    def assert_project_index_with(configuration)
      create_file ".rubocop.yml", configuration
      create_file "lib/widget.rb", <<~RUBY
        class Widget
          def render
          end
        end
      RUBY
      create_file "lib/widget_extension.rb", <<~RUBY
        class Widget
          def render
          end
        end
      RUBY

      output, error, status = inspect_project

      assert_not status.success?, "Expected RuboCop to find the cross-file duplicate.\n#{output}\n#{error}"
      assert_includes output, "Lint/DuplicateMethods", error
      assert_includes output, "is defined at both", error
      assert_empty error
    end

    def inspect_project
      RuboCopCommand.new(project).run \
        "--config", project.path_of(".rubocop.yml"),
        "--only", "Lint/DuplicateMethods",
        "--format", "simple",
        project.path_of("lib")
    end
end
