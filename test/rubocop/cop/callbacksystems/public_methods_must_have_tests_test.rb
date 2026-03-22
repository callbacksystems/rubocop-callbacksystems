require "test_helper"
require "tempfile"
require "fileutils"

class PublicMethodsMustHaveTestsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PublicMethodsMustHaveTests

  setup { @temp_dir = Dir.mktmpdir }
  teardown { FileUtils.rm_rf(@temp_dir) }

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

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
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
          "no test file"
        end
      end
    RUBY

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
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

  test "works with lib files" do
    source_file = create_file("lib/utils/string_helper.rb", <<~RUBY)
      module Utils
        class StringHelper
          def capitalize_words
            "words"
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

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "capitalize_words"
  end

  test "detects multiple missing tests" do
    source_file = create_file("app/models/user.rb", <<~RUBY)
      class User
        def method_one
          1
        end

        def method_two
          2
        end
      end
    RUBY

    create_file("test/models/user_test.rb", <<~RUBY)
      class UserTest < ActiveSupport::TestCase
      end
    RUBY

    offenses = assert_offense_in(source_file)

    assert_equal 2, offenses.count
  end

  test "works with lib files using alternate test path (test/ instead of test/lib/)" do
    source_file = create_file("lib/utils/helper.rb", <<~RUBY)
      class Helper
        def process
          "done"
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
          true
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
          true
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

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
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

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
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

  test "registers offense when test file does not exist" do
    source_file = create_file("app/controllers/checkouts_controller.rb", <<~RUBY)
      class CheckoutsController
        def index
        end
      end
    RUBY

    offenses = assert_offense_in(source_file)

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "index"
  end

  test "TestFilePathResolver resolves relative lib path to test/lib" do
    Dir.chdir(@temp_dir) do
      resolver = self.class.cop_class::TestFilePathResolver.new("lib/foo/bar.rb")
      create_file("test/lib/foo/bar_test.rb", "")

      assert_equal "test/lib/foo/bar_test.rb", resolver.resolve
    end
  end

  test "TestFilePathResolver resolves relative lib path to test/ when test/lib doesn't exist" do
    Dir.chdir(@temp_dir) do
      resolver = self.class.cop_class::TestFilePathResolver.new("lib/foo/bar.rb")
      create_file("test/foo/bar_test.rb", "")

      assert_equal "test/foo/bar_test.rb", resolver.resolve
    end
  end

  test "TestFilePathResolver resolves relative app path" do
    Dir.chdir(@temp_dir) do
      resolver = self.class.cop_class::TestFilePathResolver.new("app/models/user.rb")
      create_file("test/models/user_test.rb", "")

      assert_equal "test/models/user_test.rb", resolver.resolve
    end
  end

  test "TestedMethodsCollector finds method names with special characters" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "valid? checks validity" do
      end
      test "save! persists record" do
      end
      test "process does something" do
      end
    RUBY

    collector = self.class.cop_class::TestedMethodsCollector.new(test_file)

    assert_includes collector.collect, "valid?"
    assert_includes collector.collect, "save!"
    assert_includes collector.collect, "process"
  end

  test "TestedMethodsCollector finds setter methods ending with =" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "duration= converts integer to minutes" do
      end
      test "buffer= sets buffer duration" do
      end
    RUBY

    collector = self.class.cop_class::TestedMethodsCollector.new(test_file)

    assert_includes collector.collect, "duration="
    assert_includes collector.collect, "buffer="
  end

  test "TestedMethodsCollector finds operator methods" do
    test_file = create_file("test/example_test.rb", <<~RUBY)
      test "== returns true for same key" do
      end
      test "<=> compares by start and end times" do
      end
    RUBY

    collector = self.class.cop_class::TestedMethodsCollector.new(test_file)

    assert_includes collector.collect, "=="
    assert_includes collector.collect, "<=>"
  end

  private
    def create_file(relative_path, content)
      File.join(@temp_dir, relative_path).tap do |full_path|
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
      end
    end

    def assert_offense_in(source_file)
      assert_offense(File.read(source_file), file: source_file)
    end

    def assert_no_offense_in(source_file)
      assert_no_offense(File.read(source_file), file: source_file)
    end
end
