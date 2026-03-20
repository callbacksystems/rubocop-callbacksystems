require "test_helper"

class RuboCop::Callbacksystems::MethodCollectorTest < ActiveSupport::TestCase
  test "collect returns public method names" do
    assert_equal %i[name email], collect_from(<<~RUBY)
      class User
        def name; end
        def email; end
      end
    RUBY
  end

  test "excludes private methods" do
    assert_equal %i[name], collect_from(<<~RUBY)
      class User
        def name; end

        private
          def secret; end
      end
    RUBY
  end

  test "collects scopes" do
    assert_equal %i[published name], collect_from(<<~RUBY)
      class Article
        scope :published, -> { where(published: true) }
        def name; end
      end
    RUBY
  end

  test "collects methods from class_methods block" do
    assert_equal %i[build_with_listing some_method], collect_from(<<~RUBY)
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
  end

  test "collects methods from class << self" do
    assert_equal %i[sync retrieve name], collect_from(<<~RUBY)
      class Charge
        class << self
          def sync; end
          def retrieve; end
        end

        def name; end
      end
    RUBY
  end

  test "collects def self.method_name" do
    assert_equal %i[find_by_email name], collect_from(<<~RUBY)
      class User
        def self.find_by_email(email); end
        def name; end
      end
    RUBY
  end

  test "excludes methods from nested classes" do
    assert_equal %i[process], collect_from(<<~RUBY)
      class Outer
        def process; end

        private
          class Inner
            def helper; end
          end
      end
    RUBY
  end

  test "collects methods from included block" do
    assert_equal %i[setup_method instance_method], collect_from(<<~RUBY)
      module Concern
        included do
          def setup_method; end
        end

        def instance_method; end
      end
    RUBY
  end

  private
    def collect_from(source)
      processed = RuboCop::AST::ProcessedSource.new(source, RUBY_VERSION.to_f)
      RuboCop::Callbacksystems::MethodCollector.new(processed.ast).collect
    end
end
