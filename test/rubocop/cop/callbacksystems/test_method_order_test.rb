require "test_helper"
require "tempfile"
require "fileutils"

class RuboCop::Cop::Callbacksystems::TestMethodOrderTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::TestMethodOrder

  setup { @temp_dir = Dir.mktmpdir }

  teardown { FileUtils.remove_entry(@temp_dir) }

  test "skips non-test files" do
    assert_no_offense <<~RUBY, file: "app/models/user.rb"
      class User
        def name
        end
      end
    RUBY
  end

  test "skips when source file does not exist" do
    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/missing_test.rb"
      class MissingTest < ActiveSupport::TestCase
        test "something" do
        end
      end
    RUBY
  end

  test "allows tests in correct method order" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end

        def admin?
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
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
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "email returns address" do
        end

        test "name returns full name" do
        end
      end
    RUBY
  end

  test "allows multiple tests for same method in sequence" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def email
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
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
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end

        def admin?
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "name returns value" do
        end

        test "admin? returns true for admins" do
        end
      end
    RUBY
  end

  test "handles bang methods with exclamation mark" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def save
        end

        def save!
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "save returns boolean" do
        end

        test "save! raises on failure" do
        end
      end
    RUBY
  end

  test "ignores tests that do not match any method" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def name
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
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
    FileUtils.mkdir_p("#{@temp_dir}/app/models/account")
    File.write("#{@temp_dir}/app/models/account/billable.rb", <<~RUBY)
      module Account::Billable
        def subscription
        end

        def payment_methods
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/account/billable_test.rb"
      class Account::BillableTest < ActiveSupport::TestCase
        test "subscription returns object" do
        end

        test "payment_methods returns collection" do
        end
      end
    RUBY
  end

  test "registers offense for namespaced model with wrong order" do
    FileUtils.mkdir_p("#{@temp_dir}/app/models/account")
    File.write("#{@temp_dir}/app/models/account/billable.rb", <<~RUBY)
      module Account::Billable
        def subscription
        end

        def payment_methods
        end
      end
    RUBY

    assert_offense <<~RUBY, file: "#{@temp_dir}/test/models/account/billable_test.rb"
      class Account::BillableTest < ActiveSupport::TestCase
        test "payment_methods returns collection" do
        end

        test "subscription returns object" do
        end
      end
    RUBY
  end

  test "considers scopes in method order" do
    create_source_file "app/models/article.rb", <<~RUBY
      class Article
        scope :published, -> { where(published: true) }
        scope :draft, -> { where(published: false) }

        def title
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/article_test.rb"
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
    create_source_file "app/models/item.rb", <<~RUBY
      class Item
        scope :tagged_with, ->(tag) { where(tag: tag) }

        def tagged_with?(tag)
          self.tag == tag
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/item_test.rb"
      class ItemTest < ActiveSupport::TestCase
        test "tagged_with scope filters by tag" do
        end

        test "tagged_with? returns true when tag matches" do
        end
      end
    RUBY
  end

  test "handles class methods inside class << self" do
    create_source_file "app/models/charge.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/charge_test.rb"
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
    create_source_file "app/models/charge.rb", <<~RUBY
      class Charge
        class << self
          def sync
          end

          def retrieve_payment
          end
        end
      end
    RUBY

    assert_offense <<~RUBY, file: "#{@temp_dir}/test/models/charge_test.rb"
      class ChargeTest < ActiveSupport::TestCase
        test "retrieve_payment fetches data" do
        end

        test "sync creates charge" do
        end
      end
    RUBY
  end

  test "handles def self.method_name class methods" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        def self.find_by_email(email)
        end

        def self.create_guest
        end

        def name
        end
      end
    RUBY

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
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
    create_source_file "app/models/charge.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/charge_test.rb"
      class ChargeTest < ActiveSupport::TestCase
        test "sync creates charge" do
        end

        test "api_record returns record" do
        end
      end
    RUBY
  end

  test "registers offense when class method tests are out of order" do
    create_source_file "app/models/user.rb", <<~RUBY
      class User
        class << self
          def first_method
          end

          def second_method
          end
        end
      end
    RUBY

    assert_offense <<~RUBY, file: "#{@temp_dir}/test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        test "second_method does something" do
        end

        test "first_method does something" do
        end
      end
    RUBY
  end

  test "prioritizes top-level method over nested class method with same name" do
    create_source_file "app/models/example.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/example_test.rb"
      class ExampleTest < ActiveSupport::TestCase
        test "sync does something" do
        end

        test "instance_method does something" do
        end
      end
    RUBY
  end

  test "uses first occurrence position when method name appears multiple times" do
    create_source_file "app/models/example.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/example_test.rb"
      class ExampleTest < ActiveSupport::TestCase
        test "sync does something" do
        end

        test "other_method does something" do
        end
      end
    RUBY
  end

  test "ignores private methods" do
    create_source_file "app/models/charge.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/charge_test.rb"
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
    create_source_file "app/models/charge.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/charge_test.rb"
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
    create_source_file "app/models/order.rb", <<~RUBY
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

    assert_no_offense <<~RUBY, file: "#{@temp_dir}/test/models/order_test.rb"
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

  private
    def create_source_file(relative_path, content)
      full_path = "#{@temp_dir}/#{relative_path}"
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end
end
