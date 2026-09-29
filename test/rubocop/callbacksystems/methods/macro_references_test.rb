require "test_helper"

class RuboCop::Callbacksystems::Methods::MacroReferencesTest < ActiveSupport::TestCase
  include SourceParsing

  test "each skips a hash option whose key is not a symbol" do
    assert_empty references_in(<<~RUBY)
      validates({ "presence" => true })
    RUBY
  end

  test "each skips a delegate target that is neither a symbol nor a string" do
    assert_empty references_in(<<~RUBY)
      delegate :name, to: Currency
    RUBY
  end

  test "each skips an if condition that is neither a symbol nor a block" do
    assert_empty references_in(<<~RUBY)
      after_commit if: condition_holder
    RUBY
  end

  test "each skips a delegate target given as an empty string" do
    assert_empty references_in(<<~RUBY)
      delegate :name, to: ""
    RUBY
  end

  test "each yields a symbol argument" do
    assert_includes references_in(<<~RUBY), :notify_later
      after_commit :notify_later
    RUBY
  end

  test "each yields every symbol argument of one macro" do
    assert_equal %i[ listing_must_be_valid rules_must_be_valid ], references_in(<<~RUBY)
      validate :listing_must_be_valid, :rules_must_be_valid
    RUBY
  end

  test "each yields every symbol argument" do
    assert_equal %i[ method_one method_two ], references_in(<<~RUBY)
      after_commit :method_one
      before_save :method_two
    RUBY
  end

  test "each yields every phase of an Active Record update callback" do
    assert_equal %i[ prepare_update wrap_update finish_update ], references_in(<<~RUBY)
      before_update :prepare_update
      around_update :wrap_update
      after_update :finish_update
    RUBY
  end

  test "each yields Active Job and Action Mailer callback methods" do
    assert_equal %i[ prepare_job instrument_enqueue record_delivery ], references_in(<<~RUBY)
      before_perform :prepare_job
      around_enqueue :instrument_enqueue
      after_deliver :record_delivery
    RUBY
  end

  test "each yields methods exposed through controller macros" do
    assert_equal %i[ current_user authenticate ], references_in(<<~RUBY)
      helper_method :current_user
      skip_before_action :authenticate
    RUBY
  end

  test "each yields a rescue_from handler" do
    assert_equal %i[ handle_missing_record ], references_in(<<~RUBY)
      rescue_from RecordNotFound, with: :handle_missing_record
    RUBY
  end

  test "each skips a with option outside rescue_from" do
    assert_empty references_in(<<~RUBY)
      validates :name, with: :formatter
    RUBY
  end

  test "each skips a dynamic rescue_from handler" do
    assert_empty references_in(<<~RUBY)
      rescue_from RecordNotFound, with: handler
    RUBY
  end

  test "each skips the event and timing that configure a callback" do
    assert_equal %i[ ready? normalize ], references_in(<<~RUBY)
      set_callback :save, :before, :normalize, if: :ready?
    RUBY
  end

  test "each yields a callback removed by skip_callback" do
    assert_equal %i[ normalize ], references_in(<<~RUBY)
      skip_callback :save, :before, :normalize
    RUBY
  end

  test "each skips symbols that an unknown macro treats as data" do
    assert_empty references_in(<<~RUBY)
      validates :name, :email, presence: true
    RUBY
  end

  test "each yields references in source order, guard before action" do
    assert_equal %i[ first? second third ], references_in(<<~RUBY)
      after_commit :second, if: :first?
      before_save :third
    RUBY
  end

  test "each yields a delegate target given as a symbol" do
    assert_includes references_in(<<~RUBY), :record
      delegate :present?, to: :record
    RUBY
  end

  test "each yields the head of a delegate target given as a string chain" do
    assert_includes references_in(<<~RUBY), :config
      delegate :name, to: "config.settings"
    RUBY
  end

  test "each yields a delegate target given as a plain string" do
    assert_includes references_in(<<~RUBY), :bar
      delegate :foo, to: "bar"
    RUBY
  end

  test "each yields a delegate target given as an instance variable symbol" do
    assert_includes references_in(<<~RUBY), :@bar
      delegate :foo, to: :@bar
    RUBY
  end

  test "each skips a delegate's own method names" do
    references = references_in(<<~RUBY)
      delegate :name, :email, to: :person
    RUBY

    assert_equal %i[ person ], references
  end

  test "each skips the names an attribute macro defines" do
    assert_empty references_in(<<~RUBY)
      attr_writer :logo
      attr_reader :name
      attr_accessor :title
    RUBY
  end

  test "each skips the names store_accessor and attribute define" do
    assert_empty references_in(<<~RUBY)
      store_accessor :settings, :min, :max
      attribute :status, :string
    RUBY
  end

  test "each yields the calls a lambda callback makes" do
    assert_includes references_in(<<~RUBY), :load_record
      before_action -> { load_record }
    RUBY
  end

  test "each yields calls from a numbered-parameter callback" do
    assert_includes references_in(<<~RUBY), :load_record
      before_action -> { load_record(_1) }
    RUBY
  end

  test "each yields an if condition given as a symbol" do
    assert_equal %i[ should_notify? notify ], references_in(<<~RUBY)
      after_save :notify, if: :should_notify?
    RUBY
  end

  test "each yields an unless condition given as a symbol" do
    assert_equal %i[ skip_loading? load_user ], references_in(<<~RUBY)
      before_action :load_user, unless: :skip_loading?
    RUBY
  end

  test "each yields the calls an if condition lambda makes" do
    assert_equal %i[ should_process? process ], references_in(<<~RUBY)
      after_commit :process, if: -> { should_process? }
    RUBY
  end

  test "each yields calls from an it-parameter condition" do
    assert_equal %i[ available? process ], references_in(<<~RUBY)
      after_commit :process, if: -> { it.ready? && available? }
    RUBY
  end

  test "each yields the receiverless calls a macro block makes" do
    assert_equal %i[ helper_method other_method ], references_in(<<~RUBY)
      included do
        helper_method
        other_method
      end
    RUBY
  end

  test "each skips a call with a receiver" do
    assert_not_includes references_in(<<~RUBY), :some_method
      included do
        object.some_method
      end
    RUBY
  end

  test "each skips a block pass, which calls on elements rather than self" do
    assert_not_includes references_in(<<~RUBY), :notify
      included do
        items.each(&:notify)
      end
    RUBY
  end

  test "each reaches into nested structures" do
    assert_includes references_in(<<~RUBY), :helper
      class_methods do
        def find_by_name(name)
          helper
        end
      end
    RUBY
  end

  test "each does not cross into a nested class or singleton class" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        before_save :outer_callback

        class Inner
          before_save :inner_callback
        end

        class << self
          before_save :singleton_callback
        end
      end
    RUBY
    outer = ast

    assert_equal %i[ outer_callback ], RuboCop::Callbacksystems::Methods::MacroReferences.new(outer.body).to_a
  end

  test "each does not collect block calls across a nested class boundary" do
    assert_equal %i[ outer_helper ], references_in(<<~RUBY)
      included do
        outer_helper

        class Inner
          nested_helper
        end
      end
    RUBY
  end

  test "each visits deeply nested block calls once in source order" do
    nested = 200.times.reduce("target\n") { |body, _| "wrapper do\n#{body}end\n" }

    assert_equal %i[ wrapper target ], references_in(nested)
  end

  test "reference traversal returns an enumerator without a block" do
    body = processed_source("before_save :normalize").ast
    references = RuboCop::Callbacksystems::Methods::MacroReferences::References.new(body)

    assert_instance_of Enumerator, references.each
    assert_equal [ :normalize ], references.each.to_a
  end

  test "block calls return an enumerator without a block" do
    body = processed_source("work\nnotify").ast
    calls = RuboCop::Callbacksystems::Methods::MacroReferences::BlockCalls.new(body)

    assert_instance_of Enumerator, calls.each
    assert_equal %i[ work notify ], calls.each.to_a
  end

  test "container index keeps references by their enclosing class" do
    ast = processed_source(<<~RUBY).ast
      class First
        before_save :normalize
        def normalize; end
      end

      class Second
        def normalize; end
      end
    RUBY
    first, second = ast.each_descendant(:def).to_a
    index = RuboCop::Callbacksystems::Methods::MacroReferences::ContainerIndex.new

    assert_equal [ true, false ], [
      index.include?(:normalize, beside: first), index.include?(:normalize, beside: second)
    ]
  end

  test "container index keeps constructor block methods separate from the enclosing class" do
    ast = processed_source(<<~RUBY).ast
      class Outer
        before_save :outer_callback

        Handler = Class.new do
          before_save :inner_callback
          def outer_callback; end
          def inner_callback; end
        end
      end
    RUBY
    outer_callback, inner_callback = ast.each_descendant(:def).to_a
    index = RuboCop::Callbacksystems::Methods::MacroReferences::ContainerIndex.new

    assert_equal [ false, true ], [
      index.include?(:outer_callback, beside: outer_callback),
      index.include?(:inner_callback, beside: inner_callback)
    ]
  end

  test "each yields nothing for a nil body" do
    assert_empty RuboCop::Callbacksystems::Methods::MacroReferences.new(nil).to_a
  end

  private
    def references_in(source)
      body = processed_source(source).ast

      RuboCop::Callbacksystems::Methods::MacroReferences.new(body).to_a
    end
end
