require "test_helper"

class PublicMethodsMustHaveTestsTest < CopTestCase
  include TemporaryProject

  self.cop_class = RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests

  test "reads a test whose description is not a string literal" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def name
          read_name
        end
      end
    RUBY
    create_file("test/models/user_test.rb", <<~RUBY)
      test description do
      end
    RUBY

    assert_offense_in source_file
  end

  test "reads a block that is not a test block" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def name
          read_name
        end
      end
    RUBY
    create_file("test/models/user_test.rb", <<~RUBY)
      setup do
      end
    RUBY

    assert_offense_in source_file
  end

  test "registers offense for public method without test" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def full_name
          first_name
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "other_method works" do
          assert true
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "full_name"
  end

  test "no offense when public method has test" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def full_name
          first_name
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "full_name returns first and last name" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "does not infer missing coverage from an invalid test file" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def full_name
          first_name
        end
      end
    RUBY
    create_file("test/models/user_test.rb", "class UserTest <\n")

    assert_no_offense_in(source_file)
  end

  test "still requires coverage when the paired test file is empty but valid" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def full_name
          first_name
        end
      end
    RUBY
    create_file("test/models/user_test.rb")

    assert_offense_in(source_file)
  end

  test "no offense for private methods" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def public_method
          private_method
        end

        private
          def private_method
            "private"
          end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "public_method works" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "does not require this class's tests to cover methods defined for another runtime owner" do
    source_file = create_file("app/models/report.rb", <<~RUBY)
      class Report
        configure do
          def external_method
            calculate
          end
        end

        def OTHER.external_singleton_method
          calculate
        end

        class << OTHER
          def another_external_singleton_method
            calculate
          end
        end
      end
    RUBY
    create_file("test/models/report_test.rb")

    assert_no_offense_in(source_file)
  end

  test "requires tests only for the first singleton level of a class" do
    source_file = create_file("app/models/report.rb", <<~RUBY)
      class Report
        def self.direct
          calculate
        end

        class << self
          def first_order
            calculate
          end

          def self.second_order
            calculate
          end

          class << self
            def also_second_order
              calculate
            end
          end
        end
      end
    RUBY
    create_file("test/models/report_test.rb")

    offenses = assert_offense_in(source_file, count: 2)

    assert_equal %w[ direct first_order ], offenses.map { it.message[/`(.+?)`/, 1] }
  end

  test "does not treat the singleton of a class_methods module as the concern's API" do
    source_file = create_file("app/models/concerns/buildable.rb", <<~RUBY)
      module Buildable
        class_methods do
          def build
            calculate
          end

          def self.metadata
            calculate
          end
        end
      end
    RUBY
    create_file("test/models/concerns/buildable_test.rb")

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "build"
  end

  test "uses final runtime visibility when deciding which methods need tests" do
    source_file = create_file("app/models/report.rb", <<~RUBY)
      class Report
        def hidden
          calculate
        end
        private :hidden

        private
          public def exposed
            calculate
          end

          def self.class_side
            calculate
          end
      end
    RUBY
    create_file("test/models/report_test.rb")

    offenses = assert_offense_in(source_file, count: 2)

    assert_equal %w[ exposed class_side ], offenses.map { it.message[/`(.+?)`/, 1] }
  end

  test "no offense for methods in private nested classes" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def process
          Helper.new.run
        end

        private
          class Helper
            def run
              "running"
            end

            def untested_public_in_nested
              "no test needed"
            end
          end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "process works" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "registers offense when test file does not exist for app file" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def untested_method
          compute_value
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "untested_method"
  end

  test "no offense for test files themselves" do
    source_file = create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        def helper_method
          "helper"
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "works with lib files in gem projects" do
    create_file("my_gem.gemspec")

    source_file = create_file("lib/utils/string_helper.rb", <<~RUBY)
      module Utils
        class StringHelper
          def capitalize_words
            text.upcase
          end
        end
      end
    RUBY

    create_file("test/lib/utils/string_helper_test.rb", <<~RUBY)
      class StringHelperTest < ActiveSupport::TestCase
        test "other_method works" do
          assert true
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "capitalize_words"
  end

  test "detects multiple missing tests" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def method_one
          first_name
        end

        def method_two
          last_name
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
      end
    RUBY

    assert_offense_in(source_file, count: 2)
  end

  test "works with lib files using alternate test path (test/ instead of test/lib/)" do
    create_file("my_gem.gemspec")

    source_file = create_file("lib/utils/helper.rb", <<~RUBY)
      class Helper
        def process
          perform_work
        end
      end
    RUBY

    create_file("test/utils/helper_test.rb", <<~RUBY)
      class HelperTest < ActiveSupport::TestCase
        test "process works" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "detects test for method ending with question mark" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def valid?
          errors.empty?
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "valid? returns true" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "detects test for method ending with bang" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def save!
          persist_record
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
        test "save! persists the record" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "detects test for setter method" do
    source_file = create_file("app/models/appointment.rb", <<~RUBY)
      class Appointment
        def duration=(value)
          @duration = value.to_i.minutes
        end
      end
    RUBY

    create_file("test/models/appointment_test.rb", <<~RUBY)
      class AppointmentTest < ActiveSupport::TestCase
        test "duration= converts integer to minutes" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "detects test for equality operator" do
    source_file = create_file("app/models/plan.rb", <<~RUBY)
      class Plan
        def ==(other)
          key == other.key
        end
      end
    RUBY

    create_file("test/models/plan_test.rb", <<~RUBY)
      class PlanTest < ActiveSupport::TestCase
        test "== returns true for same key" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "detects test for spaceship operator" do
    source_file = create_file("app/models/slot.rb", <<~RUBY)
      class Slot
        def <=>(other)
          starts_at <=> other.starts_at
        end
      end
    RUBY

    create_file("test/models/slot_test.rb", <<~RUBY)
      class SlotTest < ActiveSupport::TestCase
        test "<=> compares by start time" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "requires tests for scopes" do
    source_file = create_file("app/models/article.rb", <<~RUBY)
      class Article
        scope :published, -> { where(published: true) }

        def title
          name
        end
      end
    RUBY

    create_file("test/models/article_test.rb", <<~RUBY)
      class ArticleTest < ActiveSupport::TestCase
        test "title returns the title" do
          assert true
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "published"
  end

  test "requires tests for methods in class_methods block" do
    source_file = create_file("app/models/concerns/publishable.rb", <<~RUBY)
      module Publishable
        extend ActiveSupport::Concern

        class_methods do
          def build_with_listing(attributes)
          end
        end

        def some_method
        end
      end
    RUBY

    create_file("test/models/concerns/publishable_test.rb", <<~RUBY)
      class PublishableTest < ActiveSupport::TestCase
        test "some_method does something" do
          assert true
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "build_with_listing"
  end

  test "does not require tests for methods referenced by macros" do
    source_file = create_file("app/models/order.rb", <<~RUBY)
      class Order
        after_commit :notify_later

        def total
          items.sum(:amount)
        end

        def notify_later
          NotifyJob.perform_later(self)
        end
      end
    RUBY

    create_file("test/models/order_test.rb", <<~RUBY)
      class OrderTest < ActiveSupport::TestCase
        test "total calculates sum" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "does not require tests for methods a lambda callback, its guard, or a string delegate target names" do
    source_file = create_file("app/models/order.rb", <<~RUBY)
      class Order
        before_save -> { normalize }, if: :draft?
        delegate :name, to: "customer.account"

        def total
          items.sum(:amount)
        end

        def normalize
          reference.strip!
        end

        def draft?
          status.nil?
        end

        def customer
          account.customer
        end
      end
    RUBY

    create_file("test/models/order_test.rb", <<~RUBY)
      class OrderTest < ActiveSupport::TestCase
        test "total calculates sum" do
          assert true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "registers offense when test file does not exist" do
    source_file = create_file("app/controllers/checkouts_controller.rb", <<~RUBY)
      class CheckoutsController
        def index
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "index"
  end

  test "no offense for methods returning a scalar literal" do
    source_file = create_file("app/models/plan.rb", <<~RUBY)
      class Plan
        def role
          "member"
        end

        def per_page
          25
        end

        def enabled?
          true
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "no offense for methods returning a recursively literal array or hash" do
    source_file = create_file("app/models/palette.rb", <<~RUBY)
      class Palette
        def colors
          ["red", "green", "blue"]
        end

        def defaults
          { size: 10, nested: [1, 2, { deep: true }] }
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "registers offense for interpolated string return" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def full_name
          "\#{first_name} \#{last_name}"
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "full_name"
  end

  test "registers offense for collection holding a non-literal element" do
    source_file = create_file("app/models/palette.rb", <<~RUBY)
      class Palette
        def colors
          ["red", default_color]
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "colors"
  end

  test "test_path resolves relative lib path to test/lib" do
    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("lib/foo/bar.rb")
      create_file("test/lib/foo/bar_test.rb")

      assert_equal "test/lib/foo/bar_test.rb", mapping.test_path
    end
  end

  test "test_path resolves relative lib path to test/ when test/lib doesn't exist" do
    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("lib/foo/bar.rb")
      create_file("test/foo/bar_test.rb")

      assert_equal "test/foo/bar_test.rb", mapping.test_path
    end
  end

  test "test_path resolves relative app path" do
    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("app/models/user.rb")
      create_file("test/models/user_test.rb")

      assert_equal "test/models/user_test.rb", mapping.test_path
    end
  end

  test "TestedMethods finds method names with special characters" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "valid? checks validity" do
      end
      test "save! persists record" do
      end
      test "process does something" do
      end
    RUBY

    tested = self.class.cop_class::TestedMethods.new(test_file, ruby_version: RUBY_VERSION.to_f)

    assert_includes tested, "valid?"
    assert_includes tested, "save!"
    assert_includes tested, "process"
  end

  test "TestedMethods finds setter methods ending with =" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "duration= converts integer to minutes" do
      end
      test "buffer= sets buffer duration" do
      end
    RUBY

    tested = self.class.cop_class::TestedMethods.new(test_file, ruby_version: RUBY_VERSION.to_f)

    assert_includes tested, "duration="
    assert_includes tested, "buffer="
  end

  test "TestedMethods finds operator methods" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "== returns true for same key" do
      end
      test "<=> compares by start and end times" do
      end
    RUBY

    tested = self.class.cop_class::TestedMethods.new(test_file, ruby_version: RUBY_VERSION.to_f)

    assert_includes tested, "=="
    assert_includes tested, "<=>"
  end

  test "TestedMethods treats an unreadable path as an invalid empty test" do
    tested = self.class.cop_class::TestedMethods.new \
      project.path_of("test/missing_test.rb"), ruby_version: RUBY_VERSION.to_f

    assert_not_predicate tested, :valid?
    assert_empty tested.to_a
  end

  test "skips lib files in non-gem projects" do
    source_file = create_file("lib/constraints/internal.rb", <<~RUBY)
      class Internal
        def matches?(request)
          request.local?
        end
      end
    RUBY

    assert_no_offense_in(source_file)
  end

  test "checks lib files in gem projects" do
    create_file("my_gem.gemspec")

    source_file = create_file("lib/constraints/internal.rb", <<~RUBY)
      class Internal
        def matches?(request)
          request.local?
        end
      end
    RUBY

    offenses = assert_offense_in(source_file, count: 1)

    assert_includes offenses.first.message, "matches?"
  end

  test "external_dependency_checksum follows tests and whether the project is a gem" do
    original = external_dependency_checksum

    create_file("test/example_test.rb", "test do\nend\n")

    assert_not_equal original, external_dependency_checksum

    without_gemspec = external_dependency_checksum
    create_file("example.gemspec")

    assert_not_equal without_gemspec, external_dependency_checksum
  end

  private
    def assert_offense_in(source_file, count: nil)
      assert_offense(File.read(source_file), count: count, file: source_file)
    end

    def assert_no_offense_in(source_file)
      assert_no_offense(File.read(source_file), file: source_file)
    end

    def external_dependency_checksum
      config = RuboCop::Config.new({}, project.path_of(".rubocop.yml"))

      RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests.new(config).external_dependency_checksum
    end
end
