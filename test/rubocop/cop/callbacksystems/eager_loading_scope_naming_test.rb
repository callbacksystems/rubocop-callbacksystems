require "test_helper"

class RuboCop::Cop::Callbacksystems::EagerLoadingScopeNamingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming

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

  test "handles chained scope with eager loading" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :active_with_posts, -> { where(active: true).includes(:posts) }
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

  test "allows descriptive eager loading scope names" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
        scope :with_recent_comments, -> { includes(:comments) }
        scope :with_line_items, -> { includes(:line_items) }
      end
    RUBY
  end
end
