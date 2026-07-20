require "test_helper"

class EmptyLineBeforeMethodTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EmptyLineBeforeMethod

  test "registers offense for macro directly before method" do
    assert_offense <<~RUBY
      class UsersController
        before_action :authenticate
        def index
        end
      end
    RUBY
  end

  test "registers offense for method after another non-method node" do
    assert_offense <<~RUBY
      class User
        validates :name
        def full_name
        end
      end
    RUBY
  end

  test "allows empty line before method after macro" do
    assert_no_offense <<~RUBY
      class UsersController
        before_action :authenticate

        def index
        end
      end
    RUBY
  end

  test "allows consecutive macros without empty line" do
    assert_no_offense <<~RUBY
      class User
        validates :name
        validates :email
        validates :age
      end
    RUBY
  end

  test "allows first method in class body without preceding empty line" do
    assert_no_offense <<~RUBY
      class User
        def name
        end
      end
    RUBY
  end

  test "allows method after visibility modifier without empty line" do
    assert_no_offense <<~RUBY
      class User
        def public_method
        end

        private
          def helper
          end
      end
    RUBY
  end

  test "allows method after protected without empty line" do
    assert_no_offense <<~RUBY
      class User
        protected
          def helper
          end
      end
    RUBY
  end

  test "registers offense for consecutive methods without empty line" do
    assert_offense <<~RUBY
      class User
        def name
        end
        def email
        end
      end
    RUBY
  end

  test "allows consecutive methods with empty line" do
    assert_no_offense <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY
  end

  test "registers offense for class method after macro" do
    assert_offense <<~RUBY
      class User
        scope :active, -> { where(active: true) }
        def self.find_active
        end
      end
    RUBY
  end

  test "allows class method with empty line after macro" do
    assert_no_offense <<~RUBY
      class User
        scope :active, -> { where(active: true) }

        def self.find_active
        end
      end
    RUBY
  end

  test "handles module correctly" do
    assert_offense <<~RUBY
      module Helpers
        extend ActiveSupport::Concern
        def helper_method
        end
      end
    RUBY
  end

  test "allows first method in module without empty line" do
    assert_no_offense <<~RUBY
      module Helpers
        def helper_method
        end
      end
    RUBY
  end

  test "allows first method in class_methods block without empty line" do
    assert_no_offense <<~RUBY
      module Concerns::Searchable
        class_methods do
          def search
          end
        end
      end
    RUBY
  end

  test "allows first method in included block without empty line" do
    assert_no_offense <<~RUBY
      module Concerns::Trackable
        included do
          def track
          end
        end
      end
    RUBY
  end

  test "autocorrects by inserting empty line" do
    source = <<~RUBY
      class User
        validates :name
        def full_name
        end
      end
    RUBY

    corrected = <<~RUBY
      class User
        validates :name

        def full_name
        end
      end
    RUBY

    assert_correction(source, corrected)
  end

  test "allows a describing macro glued to its method" do
    assert_no_offense <<~RUBY
      class Backup < Thor
        desc "perform", "Run a backup now"
        option :force, type: :boolean
        def perform
        end

        desc "list", "List backups"
        def list
        end
      end
    RUBY
  end

  test "registers offense when the macro group has no empty line above it" do
    offenses = assert_offense <<~RUBY
      class Backup < Thor
        desc "perform", "Run a backup now"
        def perform
        end
        desc "list", "List backups"
        def list
        end
      end
    RUBY

    assert_equal 1, offenses.size
    assert_includes offenses.first.message, "list"
  end

  test "allows a describing macro opening the body" do
    assert_no_offense <<~RUBY
      class Backup < Thor
        desc "perform", "Run a backup now"
        def perform
        end
      end
    RUBY
  end

  test "autocorrects above the macro group instead of below it" do
    assert_correction \
      <<~RUBY,
        class Backup < Thor
          desc "perform", "Run a backup now"
          def perform
          end
          desc "list", "List backups"
          def list
          end
        end
      RUBY
      <<~RUBY
        class Backup < Thor
          desc "perform", "Run a backup now"
          def perform
          end

          desc "list", "List backups"
          def list
          end
        end
      RUBY
  end
end
