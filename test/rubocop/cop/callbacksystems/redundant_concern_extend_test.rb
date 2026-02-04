require "test_helper"

class RuboCop::Cop::Callbacksystems::RedundantConcernExtendTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RedundantConcernExtend

  test "registers offense for concern without included or class_methods" do
    assert_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        def search
        end
      end
    RUBY
  end

  test "allows concern with included block" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        included do
          scope :search, -> { where(active: true) }
        end
      end
    RUBY
  end

  test "allows concern with class_methods block" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        class_methods do
          def search(query)
          end
        end
      end
    RUBY
  end

  test "allows concern with prepended block" do
    assert_no_offense <<~RUBY
      module Callbacks
        extend ActiveSupport::Concern

        prepended do
          before_save :do_something
        end
      end
    RUBY
  end

  test "allows module without concern extend" do
    assert_no_offense <<~RUBY
      module Searchable
        def search
        end
      end
    RUBY
  end

  test "registers offense for concern with only method definitions" do
    assert_offense <<~RUBY
      module Confirmable
        extend ActiveSupport::Concern

        def confirm!
        end

        def confirmed?
        end
      end
    RUBY
  end

  test "allows concern with both included and class_methods" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        included do
          scope :active, -> { where(active: true) }
        end

        class_methods do
          def search(query)
          end
        end
      end
    RUBY
  end

  test "works with just Concern constant" do
    assert_offense <<~RUBY
      module Searchable
        extend Concern

        def search
        end
      end
    RUBY
  end
end
