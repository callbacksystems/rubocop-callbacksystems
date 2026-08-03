require "test_helper"

class MacroReferencedMethodsTest < ActiveSupport::TestCase
  test "for returns a Set of referenced names when given a body" do
    body = ast <<~RUBY
      after_commit :notify
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.for(body)

    assert_kind_of Set, result
    assert_includes result, :notify
  end

  test "for returns an empty Set when body is nil" do
    result = RuboCop::Callbacksystems::MacroReferencedMethods.for(nil)

    assert_kind_of Set, result
    assert_empty result
  end

  test "all returns a Set of method names referenced in macros" do
    body = ast <<~RUBY
      after_commit :notify
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_kind_of Set, result
    assert_includes result, :notify
  end

  test "collects symbol argument" do
    body = ast <<~RUBY
      after_commit :notify_later
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :notify_later
  end

  test "collects multiple symbol arguments" do
    body = ast <<~RUBY
      after_commit :method_one
      before_save :method_two
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :method_one
    assert_includes result, :method_two
  end

  test "collects delegate to symbol" do
    body = ast <<~RUBY
      delegate :present?, to: :record
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :record
  end

  test "collects delegate to string chain" do
    body = ast <<~RUBY
      delegate :name, to: "config.settings"
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :config
  end

  test "collects delegate to string simple" do
    body = ast <<~RUBY
      delegate :foo, to: "bar"
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :bar
  end

  test "does not treat an attribute writer or accessor name as a reference" do
    body = ast <<~RUBY
      attr_writer :logo
      attr_reader :name
      attr_accessor :title
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_not_includes result, :logo
    assert_not_includes result, :name
    assert_not_includes result, :title
  end

  test "treats only a delegate's target as a reference, not its own method names" do
    body = ast <<~RUBY
      delegate :name, :email, to: :person
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_not_includes result, :name
    assert_not_includes result, :email
    assert_includes result, :person
  end

  test "does not treat store_accessor or attribute names as references" do
    body = ast <<~RUBY
      store_accessor :settings, :min, :max
      attribute :status, :string
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_not_includes result, :settings
    assert_not_includes result, :status
  end

  test "all skips the association readers a macro defines rather than calls" do
    body = ast <<~RUBY
      has_many :orders
      belongs_to :account
      has_one :profile
      has_and_belongs_to_many :tags
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_empty result
  end

  test "collects lambda callback method calls" do
    body = ast <<~RUBY
      before_action -> { load_record }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :load_record
  end

  test "collects if option symbol" do
    body = ast <<~RUBY
      after_save :notify, if: :should_notify?
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :notify
    assert_includes result, :should_notify?
  end

  test "collects unless option symbol" do
    body = ast <<~RUBY
      before_action :load_user, unless: :skip_loading?
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :load_user
    assert_includes result, :skip_loading?
  end

  test "collects if option lambda" do
    body = ast <<~RUBY
      after_commit :process, if: -> { should_process? }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :process
    assert_includes result, :should_process?
  end

  test "collects method calls from blocks" do
    body = ast <<~RUBY
      included do
        helper_method
        other_method
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :helper_method
    assert_includes result, :other_method
  end

  test "ignores calls with receiver" do
    body = ast <<~RUBY
      included do
        object.some_method
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_not_includes result, :some_method
  end

  test "handles nil body" do
    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(nil).all

    assert_empty result
  end

  test "collects from nested structures" do
    body = ast <<~RUBY
      class_methods do
        def find_by_name(name)
          helper
        end
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :helper
  end

  test "delegate to ivar symbol includes ivar symbol" do
    body = ast <<~RUBY
      delegate :foo, to: :@bar
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_includes result, :@bar
  end

  test "does not collect block_pass references (they call on elements, not self)" do
    body = ast <<~RUBY
      included do
        items.each(&:notify)
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_not_includes result, :notify
  end

  test "all skips the method a scope defines while keeping the calls in its body" do
    body = ast <<~RUBY
      scope :active, -> { confirmed }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_equal Set[:confirmed], result
  end

  test "all skips the names enum, composed_of and define_method declare" do
    body = ast <<~RUBY
      enum :status, %i[draft live]
      composed_of :balance
      define_method(:thing) { 1 }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_empty result
  end

  test "all skips the accessors the attachment and rich text macros define" do
    body = ast <<~RUBY
      has_rich_text :body
      has_one_attached :avatar
      has_many_attached :files
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_empty result
  end

  test "all takes the second name of alias_method, the one it calls" do
    body = ast <<~RUBY
      alias_method :size, :length
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_equal Set[:length], result
  end

  test "all takes the handler rescue_from is given" do
    body = ast <<~RUBY
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).all

    assert_equal Set[:not_found], result
  end

  test "ordered returns referenced names in source order, guard before action" do
    body = ast <<~RUBY
      after_commit :second, if: :first?
      before_save :third
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).ordered

    assert_equal %i[first? second third], result
  end

  private
    def ast(source)
      RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
    end
end
