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

  test "does not mistake a computed extension for Active Support Concern" do
    assert_no_offense <<~RUBY
      module Searchable
        extend extension_for(:search)

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

  test "allows a concern that includes another concern as a dependency" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern
        include Queryable
      end
    RUBY
  end

  test "allows a concern that prepends another concern as a dependency" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern
        prepend Queryable
      end
    RUBY
  end

  test "allows a conditional concern dependency" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern
        include Queryable if queryable?
      end
    RUBY
  end

  test "does not mistake an include inside a method for a concern dependency" do
    assert_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        def self.install
          include Queryable
        end
      end
    RUBY
  end

  test "allows a concern with a ClassMethods module" do
    assert_no_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern

        module ClassMethods
          def search
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

  test "works with an absolute ActiveSupport Concern constant" do
    assert_offense <<~RUBY
      module Searchable
        extend ::ActiveSupport::Concern

        def search
        end
      end
    RUBY
  end

  test "removes a redundant concern extension" do
    assert_correction <<~RUBY, <<~CORRECTED
      module Searchable
        extend ActiveSupport::Concern

        def search
        end
      end
    RUBY
      module Searchable
        def search
        end
      end
    CORRECTED
  end

  test "leaves a commented concern extension for a human rather than dropping its directive" do
    assert_uncorrectable_offense <<~RUBY
      module Searchable
        extend ActiveSupport::Concern # :nocov:

        def search
        end
      end
    RUBY
  end

  test "removes only the concern from an extension with another module" do
    assert_correction <<~RUBY, <<~CORRECTED
      module Searchable
        extend Auditable, ActiveSupport::Concern

        def search
        end
      end
    RUBY
      module Searchable
        extend Auditable

        def search
        end
      end
    CORRECTED
  end

  test "removes the concern when it leads an extension with another module" do
    assert_correction <<~RUBY, <<~CORRECTED
      module Searchable
        extend ActiveSupport::Concern, Auditable

        def search
        end
      end
    RUBY
      module Searchable
        extend Auditable

        def search
        end
      end
    CORRECTED
  end

  test "removes a same-line concern extension without deleting the method beside it" do
    assert_correction <<~RUBY, <<~CORRECTED
      module Searchable
        extend ActiveSupport::Concern; def search = records
      end
    RUBY
      module Searchable
        def search = records
      end
    CORRECTED
  end
end
