require "test_helper"

class RuboCop::Cop::Callbacksystems::SingularScopeNamesTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingularScopeNames

  test "registers offense for plural scope ending in -s" do
    assert_offense <<~RUBY
      class Person < ApplicationRecord
        scope :customers, -> { where(customer: true) }
      end
    RUBY
  end

  test "registers offense for plural scope ending in -es" do
    assert_offense <<~RUBY
      class Order < ApplicationRecord
        scope :boxes, -> { where(type: :box) }
      end
    RUBY
  end

  test "registers offense for plural scope ending in -ies" do
    assert_offense <<~RUBY
      class Order < ApplicationRecord
        scope :companies, -> { joins(:company) }
      end
    RUBY
  end

  test "allows singular scope names" do
    assert_no_offense <<~RUBY
      class Person < ApplicationRecord
        scope :customer, -> { where(customer: true) }
        scope :admin, -> { where(role: :admin) }
        scope :active, -> { where(active: true) }
      end
    RUBY
  end

  test "allows with_ prefix with plural names" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :with_posts, -> { includes(:posts) }
        scope :with_comments, -> { preload(:comments) }
        scope :with_orders, -> { eager_load(:orders) }
      end
    RUBY
  end

  test "allows exception words that look plural" do
    assert_no_offense <<~RUBY
      class Article < ApplicationRecord
        scope :news, -> { where(category: :news) }
        scope :in_progress, -> { where(status: :in_progress) }
      end
    RUBY
  end

  test "allows status as scope name" do
    assert_no_offense <<~RUBY
      class Order < ApplicationRecord
        scope :status, -> { where.not(status: nil) }
      end
    RUBY
  end

  test "allows singular adjective scopes" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        scope :active, -> { where(active: true) }
        scope :inactive, -> { where(active: false) }
        scope :recent, -> { order(created_at: :desc) }
        scope :verified, -> { where.not(verified_at: nil) }
      end
    RUBY
  end

  test "registers offense for admins" do
    assert_offense <<~RUBY
      class User < ApplicationRecord
        scope :admins, -> { where(role: :admin) }
      end
    RUBY
  end

  test "registers offense for members" do
    assert_offense <<~RUBY
      class Account < ApplicationRecord
        scope :members, -> { joins(:memberships) }
      end
    RUBY
  end
end
