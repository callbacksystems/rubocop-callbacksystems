require "test_helper"

class RuboCop::Cop::Callbacksystems::TestMethodOrderTest < CopTestCase
  include TemporaryProject

  self.cop_class = RuboCop::Cop::Callbacksystems::TestMethodOrder

  test "skips non-test files" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User
        def name
        end
      end
    RUBY
  end

  test "skips when source file does not exist" do
    assert_no_offense <<~RUBY, file: project.path_of("test/models/missing_test.rb")
      class MissingTest < ActiveSupport::TestCase
        test "something" do
        end
      end
    RUBY
  end

  test "skips when the source file holds no code" do
    create_file "app/models/user.rb", "# coming soon\n"

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        test "name returns full name" do
        end
      end
    RUBY
  end

  test "skips when the source file has invalid syntax" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name; end
        def email; end
        invalid(
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do; end
        test "name returns full name" do; end
      end
    RUBY
  end

  test "skips when the mapped source path cannot be read as a file" do
    FileUtils.mkdir_p project.path_of("app/models/user.rb")

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do; end
      end
    RUBY
  end

  test "reads the source belonging to each investigation when the cop is reused" do
    create_file "app/models/alpha.rb", <<~RUBY
      class Alpha
        def name; end
        def email; end
      end
    RUBY
    create_file "app/models/beta.rb", <<~RUBY
      class Beta
        def email; end
        def name; end
      end
    RUBY
    commissioner = RuboCop::Cop::Commissioner.new \
      [ self.class.cop_class.new(nil, autocorrect: true) ], [], raise_error: true
    alpha_test = RuboCop::ProcessedSource.new(<<~RUBY, RUBY_VERSION.to_f, project.path_of("test/models/alpha_test.rb"))
      class AlphaTest < ActiveSupport::TestCase
        test "name reads the name" do; end
        test "email reads the email" do; end
      end
    RUBY
    beta_test = RuboCop::ProcessedSource.new(<<~RUBY, RUBY_VERSION.to_f, project.path_of("test/models/beta_test.rb"))
      class BetaTest < ActiveSupport::TestCase
        test "email reads the email" do; end
        test "name reads the name" do; end
      end
    RUBY

    assert_empty commissioner.investigate(alpha_test).offenses
    assert_empty commissioner.investigate(beta_test).offenses
  end

  test "reads a changed source file again in a later investigation" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name; end
        def email; end
      end
    RUBY
    commissioner = RuboCop::Cop::Commissioner.new \
      [ self.class.cop_class.new(nil, autocorrect: true) ], [], raise_error: true
    test_file = project.path_of("test/models/user_test.rb")
    first_test = RuboCop::ProcessedSource.new(<<~RUBY, RUBY_VERSION.to_f, test_file)
      class UserTest < ActiveSupport::TestCase
        test "name reads the name" do; end
        test "email reads the email" do; end
      end
    RUBY

    assert_empty commissioner.investigate(first_test).offenses

    create_file "app/models/user.rb", <<~RUBY
      class User
        def email; end
        def name; end
      end
    RUBY
    second_test = RuboCop::ProcessedSource.new(<<~RUBY, RUBY_VERSION.to_f, test_file)
      class UserTest < ActiveSupport::TestCase
        test "email reads the email" do; end
        test "name reads the name" do; end
      end
    RUBY

    assert_empty commissioner.investigate(second_test).offenses
  end

  test "allows tests in correct method order" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end

        def admin?
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
        end

        test "email returns address" do
        end

        test "admin? returns true for admins" do
        end
      end
    RUBY
  end

  test "registers offense when tests are out of method order" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        test "name returns full name" do
        end
      end
    RUBY
  end

  test "autocorrects tests into source method order" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
          assert_equal "friend@example.com", user.email
        end

        test "name returns full name" do
          assert_equal "Ada Lovelace", user.name
        end
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
          assert_equal "Ada Lovelace", user.name
        end

        test "email returns address" do
          assert_equal "friend@example.com", user.email
        end
      end
    GOOD
  end

  test "autocorrect keeps multiple tests for one method together and stable" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        test "name returns full name" do
        end

        test "email returns nil when absent" do
        end
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
        end

        test "email returns address" do
        end

        test "email returns nil when absent" do
        end
      end
    GOOD
  end

  test "autocorrect recognizes structurally identical test blocks by identity" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name; end
        def email; end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns value" do
        end

        test "name returns value" do
        end

        test "email returns value" do
        end
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        test "name returns value" do
        end

        test "email returns value" do
        end

        test "email returns value" do
        end
      end
    GOOD
  end

  test "reads a large reversed suite without rescanning every earlier test" do
    method_names = 800.times.map { "method_#{it}" }
    create_file "app/models/report.rb", "class Report\n#{method_names.map { "  def #{it}; end\n" }.join}end\n"

    assert_offense \
      "class ReportTest\n#{method_names.reverse.map { "  test \"#{it} works\" do; end\n" }.join}end\n",
      count: 799,
      file: project.path_of("test/models/report_test.rb")
  end

  test "autocorrect carries leading comments with their tests" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        # Email behavior.
        test "email returns address" do
        end

        # Name behavior.
        test "name returns full name" do
        end
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        # Name behavior.
        test "name returns full name" do
        end

        # Email behavior.
        test "email returns address" do
        end
      end
    GOOD
  end

  test "reports without moving a test whose tooling directive would change scope" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_uncorrectable_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        # :nocov:
        test "name returns full name" do
        end
        # :nocov:
      end
    RUBY
  end

  test "does not autocorrect across a comment standing on its own between tests" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        # Both read the profile.

        test "name returns full name" do
        end
      end
    RUBY

    assert_offense source, file: project.path_of("test/models/user_test.rb")
    assert_no_correction source, file: project.path_of("test/models/user_test.rb")
  end

  test "autocorrect carries a trailing comment with its test" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end # email

        test "name returns full name" do
        end # name
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
        end # name

        test "email returns address" do
        end # email
      end
    GOOD
  end

  test "autocorrect leaves unmatched tests in their original slots" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_correction <<~BAD, <<~GOOD, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        test "validates presence" do
        end

        test "name returns full name" do
        end
      end
    BAD
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
        end

        test "validates presence" do
        end

        test "email returns address" do
        end
      end
    GOOD
  end

  test "does not autocorrect across a non-test class body statement" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    source = <<~RUBY
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        setup do
          @user = User.new
        end

        test "name returns full name" do
        end
      end
    RUBY

    file = project.path_of("test/models/user_test.rb")

    assert_uncorrectable_offense source, file: file
    assert_no_correction source, file: file
  end

  test "allows multiple tests for same method in sequence" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "name returns full name" do
        end

        test "name returns nil when blank" do
        end

        test "email returns address" do
        end
      end
    RUBY
  end

  test "handles predicate methods with question mark" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def admin?
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "name returns value" do
        end

        test "admin? returns true for admins" do
        end
      end
    RUBY
  end

  test "handles bang methods with exclamation mark" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def save
        end

        def save!
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "save returns boolean" do
        end

        test "save! raises on failure" do
        end
      end
    RUBY
  end

  test "ignores tests that do not match any method" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "validates presence of email" do
        end

        test "name returns value" do
        end

        test "creates user with defaults" do
        end
      end
    RUBY
  end

  test "handles namespaced models" do
    create_file "app/models/account/billable.rb", <<~RUBY
      module Account::Billable
        def subscription
        end

        def payment_methods
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/account/billable_test.rb")
      class Account::BillableTest < ActiveSupport::TestCase
        test "subscription returns object" do
        end

        test "payment_methods returns collection" do
        end
      end
    RUBY
  end

  test "registers offense for namespaced model with wrong order" do
    create_file "app/models/account/billable.rb", <<~RUBY
      module Account::Billable
        def subscription
        end

        def payment_methods
        end
      end
    RUBY

    assert_offense <<~RUBY, file: project.path_of("test/models/account/billable_test.rb")
      class Account::BillableTest < ActiveSupport::TestCase
        test "payment_methods returns collection" do
        end

        test "subscription returns object" do
        end
      end
    RUBY
  end

  test "considers scopes in method order" do
    create_file "app/models/article.rb", <<~RUBY
      class Article
        scope :published, -> { where(published: true) }
        scope :draft, -> { where(published: false) }

        def title
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/article_test.rb")
      class ArticleTest < ActiveSupport::TestCase
        test "published scope returns published articles" do
        end

        test "draft scope returns drafts" do
        end

        test "title returns the title" do
        end
      end
    RUBY
  end

  test "scope test does not match predicate method with same prefix" do
    create_file "app/models/item.rb", <<~RUBY
      class Item
        scope :tagged_with, ->(tag) { where(tag: tag) }

        def tagged_with?(tag)
          self.tag == tag
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/item_test.rb")
      class ItemTest < ActiveSupport::TestCase
        test "tagged_with scope filters by tag" do
        end

        test "tagged_with? returns true when tag matches" do
        end
      end
    RUBY
  end

  test "handles class methods inside class << self" do
    create_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end

          def retrieve_payment
          end
        end

        def api_record
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/charge_test.rb")
      class ChargeTest < ActiveSupport::TestCase
        test "sync creates charge" do
        end

        test "retrieve_payment fetches data" do
        end

        test "api_record returns record" do
        end
      end
    RUBY
  end

  test "registers offense when class methods tests are out of order" do
    create_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end

          def retrieve_payment
          end
        end
      end
    RUBY

    assert_offense <<~RUBY, file: project.path_of("test/models/charge_test.rb")
      class ChargeTest < ActiveSupport::TestCase
        test "retrieve_payment fetches data" do
        end

        test "sync creates charge" do
        end
      end
    RUBY
  end

  test "handles def self.method_name class methods" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        def self.find_by_email(email)
        end

        def self.create_guest
        end

        def name
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "find_by_email returns user" do
        end

        test "create_guest makes guest user" do
        end

        test "name returns full name" do
        end
      end
    RUBY
  end

  test "ignores methods from nested classes" do
    create_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end
        end

        def api_record
        end

        class Synchronizer
          def initialize
          end

          def sync
          end
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/charge_test.rb")
      class ChargeTest < ActiveSupport::TestCase
        test "sync creates charge" do
        end

        test "api_record returns record" do
        end
      end
    RUBY
  end

  test "registers offense when class method tests are out of order" do
    create_file "app/models/user.rb", <<~RUBY
      class User
        class << self
          def first_method
          end

          def second_method
          end
        end
      end
    RUBY

    assert_offense <<~RUBY, file: project.path_of("test/models/user_test.rb")
      class UserTest < ActiveSupport::TestCase
        test "second_method does something" do
        end

        test "first_method does something" do
        end
      end
    RUBY
  end

  test "prioritizes top-level method over nested class method with same name" do
    create_file "app/models/example.rb", <<~RUBY
      class Example
        class << self
          def sync
          end
        end

        def instance_method
        end

        private
          class Synchronizer
            def sync
            end
          end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/example_test.rb")
      class ExampleTest < ActiveSupport::TestCase
        test "sync does something" do
        end

        test "instance_method does something" do
        end
      end
    RUBY
  end

  test "uses first occurrence position when method name appears multiple times" do
    create_file "app/models/example.rb", <<~RUBY
      class Example
        def sync
        end

        def other_method
        end

        private
          class Synchronizer
            def sync
            end
          end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/example_test.rb")
      class ExampleTest < ActiveSupport::TestCase
        test "sync does something" do
        end

        test "other_method does something" do
        end
      end
    RUBY
  end

  test "ignores private methods" do
    create_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end

          def retrieve_payment
          end

          private
            def internal_helper
            end
        end

        def api_record
        end

        def refund!
        end

        private
          def partial_refund_data
          end

          class Synchronizer
            def sync
            end
          end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/charge_test.rb")
      class ChargeTest < ActiveSupport::TestCase
        test "sync creates charge" do
        end

        test "retrieve_payment fetches data" do
        end

        test "api_record returns record" do
        end

        test "refund! processes refund" do
        end
      end
    RUBY
  end

  test "handles real world charge.rb pattern with nested Synchronizer" do
    create_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end

          def retrieve_payment
          end

          def find_pay_customer
          end

          def charge_attributes_for
          end

          private
            def refund_attributes_for
            end

            def card_attributes_for
            end

            def charge_data_for
            end
        end

        def api_record
        end

        def refund!
        end

        def capture
        end

        def captured?
        end

        def status
        end

        private
          def partial_refund_data
          end

          class Synchronizer
            def initialize
            end

            def sync
            end

            private
              def valid?
              end

              def sync_charge
              end

              def pay_customer
              end

              def object
              end
          end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/charge_test.rb")
      class ChargeTest < ActiveSupport::TestCase
        test "sync creates charge from payment response" do
        end

        test "retrieve_payment fetches payment from API" do
        end

        test "retrieve_payment returns nil when payment not found" do
        end

        test "find_pay_customer finds customer by payer id" do
        end

        test "find_pay_customer returns nil when payer not found" do
        end

        test "charge_attributes_for converts amount to cents" do
        end

        test "charge_attributes_for extracts card brand from issuer" do
        end

        test "api_record fetches payment from API" do
        end

        test "refund! creates full refund via SDK" do
        end

        test "refund! creates partial refund via SDK" do
        end

        test "capture captures pre-authorized payment" do
        end

        test "captured? returns true when status is approved" do
        end

        test "captured? returns false when status is not approved" do
        end

        test "status returns status from data" do
        end
      end
    RUBY
  end

  test "handles methods inside blocks like has_many extensions" do
    create_file "app/models/order.rb", <<~RUBY
      class Order
        has_many :items do
          def active
          end

          def pending
          end
        end

        def total
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: project.path_of("test/models/order_test.rb")
      class OrderTest < ActiveSupport::TestCase
        test "active returns active items" do
        end

        test "pending returns pending items" do
        end

        test "total calculates sum" do
        end
      end
    RUBY
  end

  test "handles methods inside class_methods block in concern" do
    create_file "app/models/concerns/publishable.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: project.path_of("test/models/concerns/publishable_test.rb")
      class PublishableTest < ActiveSupport::TestCase
        test "build_with_listing creates record" do
        end

        test "some_method does something" do
        end
      end
    RUBY
  end

  test "registers offense when class_methods block tests are out of order" do
    create_file "app/models/concerns/publishable.rb", <<~RUBY
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

    assert_offense <<~RUBY, file: project.path_of("test/models/concerns/publishable_test.rb")
      class PublishableTest < ActiveSupport::TestCase
        test "some_method does something" do
        end

        test "build_with_listing creates record" do
        end
      end
    RUBY
  end

  test "external_dependency_checksum follows the source files the order is read against" do
    assert_not_empty RuboCop::Cop::Callbacksystems::TestMethodOrder.new.external_dependency_checksum
  end

  test "leaves alone a test with an empty description" do
    assert_no_offense <<~RUBY
      class TotalTest < ActiveSupport::TestCase
        test "" do
        end

        test "total sums the lines" do
        end
      end
    RUBY
  end
end
