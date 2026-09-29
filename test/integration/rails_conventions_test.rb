require "test_helper"
require "json"

class RailsConventionsTest < ActiveSupport::TestCase
  include TemporaryProject

  test "the shipped configuration checks eager loading everywhere outside models" do
    create_file ".rubocop.yml", <<~YAML
      plugins:
        - rubocop-callbacksystems

      AllCops:
        NewCops: enable
        SuggestExtensions: false
    YAML
    create_sources
    output, error, status = RuboCopCommand.new(project).run \
      "--only", "Callbacksystems/NoDirectEagerLoading", "--cache", "false", "--format", "json"

    assert_equal 1, status.exitstatus, "#{output}\n#{error}"
    assert_equal forbidden_paths.sort, offending_paths_in(output).sort
  end

  private
    def create_sources
      forbidden_paths.each { create_file it, "User.includes(:posts).preload(:account).eager_load(:profile)\n" }
      create_file "app/models/user.rb", "scope :with_posts, -> { includes(:posts) }\n"
      create_file "engines/billing/app/models/concerns/billable.rb", "scope :with_account, -> { preload(:account) }\n"
    end

    def forbidden_paths
      %w[
        app/controllers/users_controller.rb
        app/helpers/users_helper.rb
        app/jobs/export_users_job.rb
        app/tools/user_export.rb
        arbitrary/nested/user_query.rb
        lib/user_query.rb
      ]
    end

    def offending_paths_in(output)
      JSON.parse(output).fetch("files").filter_map do |file|
        if file.fetch("offenses").any?
          assert_equal 3, file.fetch("offenses").size

          file.fetch("path")
        end
      end
    end
end
