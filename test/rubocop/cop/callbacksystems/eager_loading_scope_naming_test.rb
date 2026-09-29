require "test_helper"

class RuboCop::Cop::Callbacksystems::EagerLoadingScopeNamingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming

  test "reads an eager loading call inside a lambda written with the keyword" do
    assert_offense <<~RUBY
      class Article
        scope :recent, lambda { includes(:line_items) }
      end
    RUBY
  end

  test "reads an eager loading call naming an association as a string" do
    assert_offense <<~RUBY
      class Article
        scope :recent, -> { includes("line_items") }
      end
    RUBY
  end

  test "allows a scope whose body is neither a block nor a lambda" do
    assert_no_offense <<~RUBY
      class Article
        scope :published, where(published: true)
      end
    RUBY
  end

  test "allows an eager loading call that names no association" do
    assert_no_offense <<~RUBY
      class Article
        scope :recent, -> { includes }
      end
    RUBY
  end

  test "allows an eager loading call whose associations are resolved at runtime" do
    assert_no_offense <<~RUBY
      class Article
        scope :recent, -> { includes(eager_associations) }
      end
    RUBY
  end

  test "reads a scope written with lambda instead of an arrow" do
    assert_offense <<~RUBY
      class Article
        scope :recent_items, lambda { includes(:line_items) }
      end
    RUBY
  end

  test "registers offense for includes scope without with_ prefix" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :including_posts, -> { includes(:posts) }
      end
    RUBY
  end

  test "registers offense for preload scope without with_ prefix" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :load_comments, -> { preload(:comments) }
      end
    RUBY
  end

  test "registers offense for eager_load scope without with_ prefix" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :eager_profile, -> { eager_load(:profile) }
      end
    RUBY
  end

  test "allows with_ prefix for includes" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
      end
    RUBY
  end

  test "allows with_ prefix for preload" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_comments, -> { preload(:comments) }
      end
    RUBY
  end

  test "allows with_ prefix for eager_load" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_profile, -> { eager_load(:profile) }
      end
    RUBY
  end

  test "allows scopes without eager loading" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :active, -> { where(active: true) }
        scope :recent, -> { order(created_at: :desc) }
      end
    RUBY
  end

  test "reserves with prefix for eager loading rather than filtering" do
    offenses = assert_offense <<~RUBY, count: 1
      class User < ActiveRecord::Base
        scope :with_active, -> { where(active: true) }
      end
    RUBY

    assert_includes offenses.first.message, "Reserve `with_*` for eager loading scopes"
  end

  test "reserves with prefix for eager loading rather than query ordering and joins" do
    assert_offense <<~RUBY, count: 3
      class User < ActiveRecord::Base
        scope :with_recent, -> { order(created_at: :desc) }
        scope :with_posts, -> { joins(:posts) }
        scope :with_active, -> { self.where(active: true).order(:name).limit(10) }
      end
    RUBY
  end

  test "reserves with prefix when a parameterized scope only filters" do
    assert_offense <<~RUBY
      class User < ActiveRecord::Base
        scope :with_status, ->(status) { where(status:) }
      end
    RUBY
  end

  test "reserves with prefix when a scope only negates a where clause" do
    assert_offense <<~RUBY
      class User < ActiveRecord::Base
        scope :with_active, -> { where.not(blocked: true) }
      end
    RUBY
  end

  test "allows with prefix for custom negation methods" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_active, -> { self.not(blocked: true) }
        scope :with_ready, -> { query.not(blocked: true) }
        scope :with_recent, -> { where(active: true).not(blocked: true) }
      end
    RUBY
  end

  test "allows with prefix when a custom block builds the scope callable" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_active, query_for { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix on a query scope declared without a known owner" do
    assert_no_offense "scope :with_active, -> { where(active: true) }"
  end

  test "allows with prefix when eager loading associations are dynamic" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { includes(association_names).where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a scope composes another scope" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_recent_posts, -> { with_posts.order(created_at: :desc) }
        scope :with_profile, -> { profile_query }
        scope :with_active, -> { merge(active_query) }
        scope :with_posts, -> { where(active: true).merge(post_query) }
      end
    RUBY
  end

  test "allows with prefix when a query receiver is not known" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_recent, -> { Query.new.where(active: true) }
        scope :with_active, ->(relation) { relation.where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when eager loading comes from a default scope" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        default_scope { includes(:posts) }
        scope :with_active_posts, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when default scope is a singleton method" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        def self.default_scope
          includes(:posts)
        end

        scope :with_active_posts, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when default scope is inherited" do
    assert_no_offense <<~RUBY
      class Entry < ActiveRecord::Base
        default_scope { includes(:author) }
      end

      class Post < Entry
        scope :with_recent_author, -> { where(recent: true) }
      end
    RUBY
  end

  test "allows with prefix when default scope comes from a concern" do
    assert_no_offense <<~RUBY
      module Authored
        extend ActiveSupport::Concern
        included { default_scope { includes(:author) } }
      end

      class Post < ActiveRecord::Base
        include Authored
        scope :with_recent_author, -> { where(recent: true) }
      end
    RUBY
  end

  test "allows with prefix when an indexed ancestor defines default scope in another file" do
    sources = {
      "app/models/application_record.rb" => <<~RUBY
        class ApplicationRecord < ActiveRecord::Base
          default_scope { includes(:author) }
        end
      RUBY
    }

    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ApplicationRecord
        scope :with_recent_author, -> { where(recent: true) }
      end
    RUBY
  end

  test "allows with prefix when an indexed concern defines default scope in another file" do
    sources = {
      "app/models/concerns/authored.rb" => <<~RUBY
        module Authored
          extend ActiveSupport::Concern
          included { default_scope { includes(:author) } }
        end
      RUBY
    }

    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ActiveRecord::Base
        include Authored
        scope :with_recent_author, -> { where(recent: true) }
      end
    RUBY
  end

  test "reserves with prefix when an indexed Rails ancestor has no default scope" do
    sources = { "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base; end" }

    assert_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when an ancestor cannot be read without an index" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a concern cannot be read without an index" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        include Authored
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when the receiving model of a concern is unknown" do
    assert_no_offense <<~RUBY
      module Authored
        scope :with_author, -> { where(author: true) }

        included do
          scope :with_active, -> { where(active: true) }
        end
      end
    RUBY
  end

  test "allows with prefix when evaluation changes the scope receiver inside a class" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        default_scope { includes(:posts) }
      end

      class Installer
        User.class_eval do
          scope :with_active_posts, -> { where(active: true) }
        end
      end
    RUBY
  end

  test "reserves with prefix when a class has no inherited defaults" do
    assert_offense <<~RUBY
      class User
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a singleton section defines default scope" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        class << self
          def default_scope
            includes(:posts)
          end
        end

        scope :with_active_posts, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when an earlier reopening defines default scope without an index" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        default_scope { includes(:posts) }
      end

      class User
        scope :with_active_posts, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a relative framework name is shadowed without an index" do
    assert_no_offense <<~RUBY
      module Tenant
        module ActiveRecord
          class Base
            default_scope { includes(:posts) }
          end
        end

        class User < ActiveRecord::Base
          scope :with_active_posts, -> { where(active: true) }
        end
      end
    RUBY
  end

  test "reserves with prefix when a namespaced class explicitly inherits the framework base" do
    assert_offense <<~RUBY
      module Tenant
        class User < ::ActiveRecord::Base
          scope :with_active, -> { where(active: true) }
        end
      end
    RUBY
  end

  test "reserves with prefix when a resolved concern has no default scope" do
    sources = {
      "app/models/concerns/authored.rb" => <<~RUBY
        module Authored
          extend ::ActiveSupport::Concern
          included { belongs_to :author }
        end
      RUBY
    }

    assert_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ActiveRecord::Base
        include Authored
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when an extended module defines default scope" do
    sources = {
      "app/models/concerns/authored.rb" => <<~RUBY
        module Authored
          def default_scope
            includes(:author)
          end
        end
      RUBY
    }

    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ActiveRecord::Base
        extend Authored
        scope :with_recent_author, -> { where(recent: true) }
      end
    RUBY
  end

  test "reserves with prefix without borrowing defaults from a namespaced namesake" do
    sources = {
      "app/models/application_record.rb" => <<~RUBY
        module Tenant
          class ApplicationRecord < ActiveRecord::Base
            default_scope { includes(:author) }
          end
        end

        class ApplicationRecord < ActiveRecord::Base
        end
      RUBY
    }

    assert_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a project index cannot resolve an ancestor" do
    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: {}
      class Post < MissingRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a project index cannot resolve a dynamic concern" do
    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: {}
      class Post < ActiveRecord::Base
        include configured_concern
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when a dynamic concern cannot be read without an index" do
    assert_no_offense <<~RUBY
      class Post < ActiveRecord::Base
        include configured_concern
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with prefix when an indexed ancestor source disappears" do
    source = <<~RUBY
      class Post < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
    project_index = project_index_for \
      DEFAULT_FILE => source,
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base; end"
    File.delete(project.path_of("app/models/application_record.rb"))
    investigation = CopTestCase::CopInvestigation.new \
      self.class.cop_class, source, project.path_of(DEFAULT_FILE), nil, project_index

    assert_empty investigation.offenses
  end

  test "allows with prefix when an indexed ancestor source no longer matches its definition" do
    source = <<~RUBY
      class Post < ApplicationRecord
        scope :with_active, -> { where(active: true) }
      end
    RUBY
    project_index = project_index_for \
      DEFAULT_FILE => source,
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base; end"
    create_file "app/models/application_record.rb", "class ApplicationRecord < ActiveRecord::Base; default_scope; end"
    investigation = CopTestCase::CopInvestigation.new \
      self.class.cop_class, source, project.path_of(DEFAULT_FILE), nil, project_index

    assert_empty investigation.offenses
  end

  test "allows with prefix when the index cannot resolve the scope owner" do
    source = <<~RUBY
      class Post < ActiveRecord::Base
        scope :with_active, -> { where(active: true) }
      end
    RUBY
    project_index = project_index_for("app/models/other.rb" => "class Other; end")
    create_file DEFAULT_FILE, source
    investigation = CopTestCase::CopInvestigation.new \
      self.class.cop_class, source, project.path_of(DEFAULT_FILE), nil, project_index

    assert_empty investigation.offenses
  end

  test "allows with prefix when reflection leaves an external reopening uncertain" do
    sources = {
      "app/models/post_defaults.rb" => <<~RUBY
        class Post
          default_scope { includes(:author) }
        end

        Post.class_eval(configuration)
      RUBY
    }

    assert_no_offense <<~RUBY, file: "app/models/post.rb", project_sources: sources
      class Post < ActiveRecord::Base
        scope :with_active, -> { where(active: true) }
      end
    RUBY
  end

  test "still requires with prefix for explicit eager loading when an index is unreliable" do
    assert_offense <<~RUBY, file: "app/models/post.rb", project_sources: {}
      class Post < ActiveRecord::Base
        include configured_concern
        scope :loaded, -> { includes(:posts) }
      end
    RUBY
  end

  test "allows with prefix when a conditional query may eager load" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { ready? ? loaded_query : none }
      end
    RUBY
  end

  test "allows with prefix when a scope body dispatches dynamically" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { public_send(query_method) }
      end
    RUBY
  end

  test "does not infer eager loading from a callable supplied as a scope body" do
    assert_no_offense <<~RUBY
      class User < ActiveRecord::Base
        scope :with_posts, configured_query
        scope :with_profile, -> { }
      end
    RUBY
  end

  test "handles chained scope with eager loading" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :active_with_posts, -> { where(active: true).includes(:posts) }
      end
    RUBY
  end

  test "handles safely navigated eager loading" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :active_posts, -> { current_scope&.includes(:posts) }
      end
    RUBY
  end

  test "ignores eager loading hidden in a nested deferred callable" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :active, -> { proc { includes(:posts) } }
      end
    RUBY
  end

  test "allows with_ prefix in chained scope" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_active_posts, -> { where(active: true).includes(:posts) }
      end
    RUBY
  end

  test "registers offense for scope containing controller action show" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_show_data, -> { includes(:profile) }
      end
    RUBY

    assert offenses.any? { it.message.include?("controller action `show`") }
  end

  test "registers offense for scope containing controller action index" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_index_items, -> { includes(:items) }
      end
    RUBY

    assert offenses.any? { it.message.include?("controller action `index`") }
  end

  test "registers offense for scope containing generic term associations" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_associations, -> { includes(:posts) }
      end
    RUBY

    assert offenses.any? { it.message.include?("generic term `associations`") }
  end

  test "registers offense for scope containing generic term relations" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_relations, -> { includes(:comments) }
      end
    RUBY

    assert offenses.any? { it.message.include?("generic term `relations`") }
  end

  test "keeps every naming problem in the offense for one scope name" do
    offenses = assert_offense <<~RUBY, count: 1
      class User < ApplicationRecord
        scope :show_associations, -> { includes(:posts) }
      end
    RUBY

    assert offenses.any? { it.message.include?("`with_*` convention") }
    assert offenses.any? { it.message.include?("controller action `show`") }
    assert offenses.any? { it.message.include?("generic term `associations`") }
  end

  test "allows descriptive eager loading scope names" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
        scope :with_recent_comments, -> { includes(:comments) }
        scope :with_line_items, -> { includes(:line_items) }
      end
    RUBY
  end

  test "allows a scope with an empty body" do
    assert_no_offense <<~RUBY, file: "app/models/post.rb"
      class Post < ApplicationRecord
        scope :recent, -> { }
      end
    RUBY
  end

  test "suggests a valid name for a nested association hash" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :loaded, -> { includes(posts: :comments) }
      end
    RUBY

    assert_includes offenses.first.message, "`with_posts`"
  end

  test "names every top-level eager loaded association" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :loaded, -> { includes(:profile, posts: :comments) }
      end
    RUBY

    assert_includes offenses.first.message, "`with_profile_and_posts`"
  end

  test "names eager loaded associations supplied in arrays" do
    offenses = assert_offense <<~RUBY, count: 3
      class User < ApplicationRecord
        scope :loaded_posts, -> { includes([:posts]) }
        scope :loaded_comments, -> { preload([:comments]) }
        scope :loaded_profile, -> { eager_load([:profile]) }
      end
    RUBY

    assert_includes offenses.first.message, "`with_posts`"
  end

  test "names nested association arrays without promoting nested hash values" do
    offenses = assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :loaded, -> { includes([[:profile], { posts: [:comments, :author] }, "account"]) }
      end
    RUBY

    assert_includes offenses.first.message, "`with_profile_and_posts_and_account`"
  end

  test "association names can be enumerated without an immediate block" do
    argument = RuboCop::ProcessedSource.new(":posts", RUBY_VERSION.to_f).ast
    names = RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming::AssociationNames.new(argument)

    assert_equal [ "posts" ], names.each.to_a
  end
end
