require "test_helper"

class MacroReferencedMethodsTest < ActiveSupport::TestCase
  test "collects symbol argument" do
    body = parse_body <<~RUBY
      after_commit :notify_later
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :notify_later
  end

  test "collects multiple symbol arguments" do
    body = parse_body <<~RUBY
      after_commit :method_one
      before_save :method_two
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :method_one
    assert_includes result, :method_two
  end

  test "collects delegate to symbol" do
    body = parse_body <<~RUBY
      delegate :present?, to: :record
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :record
  end

  test "collects delegate to string chain" do
    body = parse_body <<~RUBY
      delegate :name, to: "config.settings"
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :config
  end

  test "collects delegate to string simple" do
    body = parse_body <<~RUBY
      delegate :foo, to: "bar"
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :bar
  end

  test "collects lambda callback method calls" do
    body = parse_body <<~RUBY
      before_action -> { load_record }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :load_record
  end

  test "collects if option symbol" do
    body = parse_body <<~RUBY
      after_save :notify, if: :should_notify?
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :notify
    assert_includes result, :should_notify?
  end

  test "collects unless option symbol" do
    body = parse_body <<~RUBY
      before_action :load_user, unless: :skip_loading?
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :load_user
    assert_includes result, :skip_loading?
  end

  test "collects if option lambda" do
    body = parse_body <<~RUBY
      after_commit :process, if: -> { should_process? }
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :process
    assert_includes result, :should_process?
  end

  test "collects method calls from blocks" do
    body = parse_body <<~RUBY
      included do
        helper_method
        other_method
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :helper_method
    assert_includes result, :other_method
  end

  test "ignores calls with receiver" do
    body = parse_body <<~RUBY
      included do
        object.some_method
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_not_includes result, :some_method
  end

  test "handles nil body" do
    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(nil).collect

    assert_empty result
  end

  test "collects from nested structures" do
    body = parse_body <<~RUBY
      class_methods do
        def find_by_name(name)
          helper
        end
      end
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :helper
  end

  test "delegate to ivar symbol includes ivar symbol" do
    body = parse_body <<~RUBY
      delegate :foo, to: :@bar
    RUBY

    result = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

    assert_includes result, :@bar
  end

  private
    def parse_body(source)
      parsed = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
      parsed.ast
    end
end
