require "test_helper"

class RuboCop::Cop::Callbacksystems::NoDirectEagerLoadingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoDirectEagerLoading

  test "registers offense for includes in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.includes(:posts)
        end
      end
    RUBY
  end

  test "registers offense for preload in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.preload(:comments)
        end
      end
    RUBY
  end

  test "registers offense for eager_load in controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def show
          @user = User.eager_load(:profile).find(params[:id])
        end
      end
    RUBY
  end

  test "registers offense in nested controller" do
    assert_offense <<~RUBY, file: "app/controllers/admin/users_controller.rb"
      class Admin::UsersController < ApplicationController
        def index
          @users = User.includes(:posts, :comments)
        end
      end
    RUBY
  end

  test "allows includes in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
      end
    RUBY
  end

  test "allows preload in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_comments, -> { preload(:comments) }
      end
    RUBY
  end

  test "allows eager_load in model" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User < ApplicationRecord
        scope :with_profile, -> { eager_load(:profile) }
      end
    RUBY
  end

  test "allows scope usage in controller" do
    assert_no_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        def index
          @users = User.with_posts.all
        end
      end
    RUBY
  end

  test "registers offense in a support class stored beside a controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UserQuery
        def call
          User.includes(:posts)
        end
      end
    RUBY
  end

  test "registers offense in a class builder nested in a controller" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      class UsersController < ApplicationController
        Handler = Class.new(BaseHandler) do
          def records
            User.includes(:posts)
          end
        end
      end
    RUBY
  end

  test "registers offense at the top level of a controller file" do
    assert_offense <<~RUBY, file: "app/controllers/users_controller.rb"
      User.includes(:posts)
    RUBY
  end

  test "registers offenses in jobs tools helpers and libraries" do
    %w[ app/jobs/report_job.rb app/tools/user_query.rb app/helpers/users_helper.rb lib/report.rb ].each do |file|
      assert_offense "User.includes(:posts)", file:
    end
  end

  test "registers offenses in arbitrary directories outside models" do
    assert_offense <<~RUBY, file: "arbitrary/nested/report.rb", count: 3
      records.includes(:posts)
      records.preload(:account)
      records.eager_load(:profile)
    RUBY
  end

  test "registers an offense on a chained query outside models" do
    assert_offense <<~RUBY, file: "app/tools/user_query.rb"
      class UserQuery
        def call
          User.where(active: true).preload(:posts)
        end
      end
    RUBY
  end

  test "registers an offense on a relation variable outside models" do
    assert_offense "users.preload(:posts)", file: "lib/report.rb"
  end

  test "registers an offense on a safely navigated relation outside models" do
    assert_offense "users&.eager_load(:profile)", file: "app/jobs/report_job.rb"
  end

  test "leaves zero argument calls outside the association loading API" do
    assert_no_offense <<~RUBY, file: "lib/loading.rb"
      records.includes
      records.preload
      records.eager_load
      loader.eager_load
    RUBY
  end

  test "keeps association loading with splats and nested associations in scope" do
    assert_offense <<~RUBY, file: "app/tools/report.rb", count: 3
      records.includes(*association_names)
      records.preload(posts: :comments)
      records.eager_load([:profile, :posts])
    RUBY
  end

  test "registers an offense on a receiverless call outside models" do
    assert_offense <<~RUBY, file: "lib/user_queries.rb"
      module UserQueries
        def recent
          includes(:posts)
        end
      end
    RUBY
  end

  test "allows eager loading in model concerns and engine models" do
    %w[ app/models/concerns/user_queries.rb engines/admin/app/models/user.rb ].each do |file|
      assert_no_offense "User.includes(:posts)", file:
    end
  end

  test "does not mistake a similarly named directory for app models" do
    %w[ lib/app_models/user.rb app/models_archive/user.rb test/models/user_test.rb ].each do |file|
      assert_offense "User.includes(:posts)", file:
    end
  end

  test "allows calls to an explicitly defined instance method on self" do
    assert_no_offense <<~RUBY, file: "lib/document.rb"
      class Document
        def includes(name)
          sections.include?(name)
        end

        def complete?
          includes(:title) && self.includes(:body)
        end
      end
    RUBY
  end

  test "allows a constant receiver with an explicitly defined singleton method" do
    assert_no_offense <<~RUBY, file: "lib/documents.rb"
      class Document
        def self.includes(name)
          sections.include?(name)
        end
      end

      Document.includes(:title)
    RUBY
  end

  test "allows a singleton section defining an application method" do
    assert_no_offense <<~RUBY, file: "lib/documents.rb"
      module Document
        class << self
          def preload(name)
            read(name)
          end
        end
      end

      Document.preload(:title)
    RUBY
  end

  test "does not hide query calls because another receiver defines the same method" do
    assert_offense <<~RUBY, file: "app/tools/report.rb"
      class Document
        def self.includes(name); end
        def self.preload(name); end
        def includes(name); end
      end

      User.includes(:posts)
    RUBY
  end

  test "does not confuse an instance method with a singleton query method" do
    assert_offense <<~RUBY, file: "lib/users.rb"
      class User
        def includes(name); end
      end

      User.includes(:posts)
    RUBY
  end

  test "does not attribute a definition inside a deferred block to its enclosing class" do
    assert_offense <<~RUBY, file: "lib/users.rb"
      class User
        install do
          def self.includes(name); end
        end
      end

      User.includes(:posts)
    RUBY
  end
end
