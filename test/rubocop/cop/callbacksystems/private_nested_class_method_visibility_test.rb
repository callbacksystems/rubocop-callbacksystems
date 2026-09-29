require "test_helper"

class PrivateNestedClassMethodVisibilityTest < CopTestCase
  include SourceParsing

  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateNestedClassMethodVisibility
  self.project_indexed = true

  test "reads a receiverless new without mistaking it for the nested class" do
    assert_offense <<~RUBY
      class Foo
        def process
          new
          Bar.new.used_method
          nil
        end

        private
          class Bar
            def used_method; end
            def unused_method; end
          end
      end
    RUBY
  end

  test "reads an anonymous block pass without a symbol to read" do
    assert_offense <<~RUBY
      class Foo
        def process(&)
          Bar.new.used_method
          forward(&)
        end

        private
          class Bar
            def used_method; end
            def unused_method; end
          end
      end
    RUBY
  end

  test "counts a delegate outside the class as a use of the names it forwards" do
    assert_no_offense <<~RUBY
      class Foo
        delegate :used_method, to: :thing

        def process
          Bar.new.used_method
        end

        private
          class Bar
            def used_method; end
          end
      end
    RUBY
  end

  test "counts a delegate name without requiring a direct call outside the class" do
    assert_no_offense <<~RUBY
      class Container
        delegate :status, to: :worker

        private
          class Worker
            def status; end
          end
      end
    RUBY
  end

  test "registers offense for unused public method in private nested class" do
    offenses = assert_offense <<~RUBY, count: 1
      class Foo
        def process
          Bar.new(node).used_method
          nil
        end

        private
          class Bar
            def used_method; end
            def unused_method; end
          end
      end
    RUBY

    assert_includes offenses.first.message, "unused_method"
  end

  test "does not infer unused methods without the source root" do
    root = processed_source(<<~RUBY).ast
      class Foo
        private
          class Bar
            def unused_method; end
          end
      end
    RUBY
    nested_class = root.each_descendant(:class).first
    analysis = self.class.cop_class::UnusedPublicMethods.new(nested_class, references: nil)

    assert_empty analysis.enum_for(:each_offense).to_a
  end

  test "does not infer project confinement without the project index" do
    assert_no_offense <<~RUBY, project_sources: false
      class Container
        private
          class Worker
            def unused_method; end
          end
      end
    RUBY
  end

  test "does not infer confinement while any indexed file has a parse error" do
    project_sources = { "app/models/broken.rb" => "class Broken\n" }

    assert_no_offense <<~RUBY, file: "app/models/container.rb", project_sources:
      class Container
        private
          class Worker
            def unused_method; end
          end
      end
    RUBY
  end

  test "leaves visibility alone when a dynamic modifier makes the declaration ambiguous" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process; end
            private ENV.fetch("METHOD", :process)
          end
      end
    RUBY
  end

  test "leaves public methods alone when the nested class has a superclass" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker < BaseWorker
            def framework_hook; end
          end
      end
    RUBY
  end

  test "leaves public methods alone when the nested class uses a mixin" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            include WorkerCallbacks

            def framework_hook; end
          end
      end
    RUBY
  end

  test "leaves public methods alone when the class object is handed off" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def externally_used; end
          end
      end

      registry.register(Container::Worker)
    RUBY
  end

  test "does not confuse a handed-off class with later constants after multibyte source" do
    assert_no_offense <<~RUBY
      module Unused
        Thing = 1
      end

      class Container
        def publish_worker
          "éééééééééééé"; publish(Worker);    Worker.new; Unused::Thing
        end

        private
          class Worker
            def externally_used; end
          end
      end
    RUBY
  end

  test "leaves public methods alone when a class factory can hand out an instance" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def self.build
              new
            end

            def externally_used; end
          end
      end
    RUBY
  end

  test "leaves public methods alone when another file reaches the visually private class" do
    external_source = <<~RUBY
      Container::Worker.new.process
    RUBY
    source = <<~RUBY
      class Container
        private
          class Worker
            def process; end
          end
      end
    RUBY

    assert_no_offense source, file: "app/models/container.rb",
      project_sources: { "app/jobs/process_worker_job.rb" => external_source }
  end

  test "leaves public methods alone when another file reopens the visually private class" do
    external_source = <<~RUBY
      class Container::Worker
      end
    RUBY
    source = <<~RUBY
      class Container
        private
          class Worker
            def unused_method; end
          end
      end
    RUBY

    assert_no_offense source, file: "app/models/container.rb",
      project_sources: { "app/models/container/worker.rb" => external_source }
  end

  test "leaves public methods alone when the visually private class is reopened in the same file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def unused_method; end
          end
      end

      class Container::Worker
      end
    RUBY
  end

  test "leaves public methods alone when the visually private class has a descendant" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def unused_method; end
          end
      end

      class SpecializedWorker < Container::Worker
      end
    RUBY
  end

  test "leaves public methods alone when the visually private class may have a dynamic descendant" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def unused_method; end
          end
      end

      parent = Container::Worker

      class SpecializedWorker < parent
      end
    RUBY
  end

  test "no offense when all public methods are called from outside" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          bar = Bar.new(node)
          bar.method_one
          bar.method_two
        end

        private
          class Bar
            def method_one; end
            def method_two; end
          end
      end
    RUBY
  end

  test "no offense for method called on a memoized instance variable" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          @entry ||= Entry.new(node)
          @entry.commit
        end

        private
          class Entry
            def initialize(node)
              @node = node
            end

            def commit
            end
          end
      end
    RUBY
  end

  test "no offense for method called on a method returning an instance" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          entry.commit
        end

        private
          def entry
            Entry.new(node)
          end

          class Entry
            def initialize(node)
              @node = node
            end

            def commit
            end
          end
      end
    RUBY
  end

  test "no offense for method called on a memoized method returning an instance" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          entry.commit
        end

        private
          def entry
            @entry ||= Entry.new(node)
          end

          class Entry
            def initialize(node)
              @node = node
            end

            def commit
            end
          end
      end
    RUBY
  end

  test "registers offense for a method a discarded instance never calls" do
    offenses = assert_offense <<~RUBY, count: 1
      class Foo
        def process
          Entry.new(node).commit
          nil
        end

        private
          class Entry
            def commit
            end

            def rollback
            end
          end
      end
    RUBY

    assert_includes offenses.first.message, "rollback"
  end

  test "no offense for private methods in nested class" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).public_method
        end

        private
          class Bar
            def public_method
              private_helper
            end

            private
              def private_helper; end
          end
      end
    RUBY
  end

  test "no offense for nested class not in private section" do
    assert_no_offense <<~RUBY
      class Foo
        class Bar
          def unused_method; end
        end

        def process
          Bar.new(node).other_method
        end
      end
    RUBY
  end

  test "no offense for initialize method" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).used
        end

        private
          class Bar
            def initialize(node)
              @node = node
            end

            def used; end
          end
      end
    RUBY
  end

  test "no offense for method referenced by callback symbol" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            after_initialize :setup

            def run; end

            def setup
              @ready = true
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by an unknown DSL" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            on_event :status

            def status; end
          end
      end
    RUBY
  end

  test "no offense when a mixin is included through explicit self" do
    assert_no_offense <<~RUBY
      module Publisher
        def publish
          $worker = self
        end
      end

      class Container
        def process
          Worker.new.publish
          nil
        end

        private
          class Worker
            self.include Publisher

            def externally_used; end
          end
      end
    RUBY
  end

  test "no offense for method referenced by delegate to: symbol" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            delegate :present?, to: :record

            def run; end

            def record
              @record ||= find_record
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by delegate to: string chain" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            delegate :name, to: "config.settings"

            def run; end

            def config
              @config ||= load_config
            end
          end
      end
    RUBY
  end

  test "leaves public methods alone when delegate_missing_to outside can reach them" do
    assert_no_offense <<~RUBY
      class Foo
        delegate_missing_to :worker

        private
          class Worker
            def perform
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced by lambda callback" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            before_action -> { prepare_data }

            def run; end

            def prepare_data
              @data = []
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced in callback if: option" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            after_save :notify, if: :should_notify?

            def run; end

            def notify; end

            def should_notify?
              true
            end
          end
      end
    RUBY
  end

  test "no offense for method referenced in callback unless: option" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            before_save :validate_data, unless: :skip_validation?

            def run; end

            def validate_data; end

            def skip_validation?
              false
            end
          end
      end
    RUBY
  end

  test "no offense for method called in block" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          Bar.new(node).run
        end

        private
          class Bar
            included do
              helper_method
            end

            def run; end

            def helper_method; end
          end
      end
    RUBY
  end

  test "no offense for method called via block-pass" do
    assert_no_offense <<~RUBY
      class Foo
        def process
          items.each(&:run)
        end

        private
          class Bar
            def run; end
          end
      end
    RUBY
  end

  test "no offense for method called via block-pass on collection of nested class instances" do
    assert_no_offense <<~RUBY
      class Page::Offer::Revision
        def revise
          valid? && commit
        end

        private
          def commit_listings
            listing_entries.each(&:commit)
          end

          def listing_entries
            @listing_entries || []
          end

          class ListingEntry
            attr_reader :listing, :rules

            def initialize(listing, entry, position:)
              @listing = listing
            end

            def commit
              listing.save!
            end
          end
      end
    RUBY
  end

  test "no offense when outer class shares a method name with the nested class" do
    assert_no_offense <<~RUBY
      class Page::Offer::Revision
        def revise
          valid? && commit
        end

        private
          def commit
            true
          end

          def commit_listings
            listing_entries.each(&:commit)
          end

          def listing_entries
            @listing_entries || []
          end

          class ListingEntry
            def initialize(listing)
              @listing = listing
            end

            def commit
              listing.save!
            end
          end
      end
    RUBY
  end

  test "no offense when a duplicate instance calls the method" do
    assert_no_offense <<~RUBY
      class Container
        def process
          Worker.new.run
          nil
        end

        private
          class Worker
            def run
              dup.status
              nil
            end

            def status; end
          end
      end
    RUBY
  end

  test "no offense when a block pass publicly dispatches the method" do
    assert_no_offense <<~RUBY
      class Container
        def process
          Worker.new.run
          nil
        end

        private
          class Worker
            def run
              [ dup ].each(&:status)
              nil
            end

            def status; end
          end
      end
    RUBY
  end

  test "no offense when public reflection reads the method" do
    assert_no_offense <<~RUBY
      class Container
        def process
          Worker.new.run
          nil
        end

        private
          class Worker
            def run
              public_method(:status)
              respond_to?(:status)
              nil
            end

            def status; end
          end
      end
    RUBY
  end

  test "no offense when public reflection reads the method elsewhere in the file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def status; end
          end
      end

      Container::Worker.new.respond_to?(:status)
      nil
    RUBY
  end

  test "no offense when Active Support dynamically dispatches a public method" do
    assert_no_offense <<~RUBY
      class Container
        def process(method_name)
          Worker.new.try(method_name)
          Worker.new.try!(method_name)
          nil
        end

        private
          class Worker
            def perform; end
          end
      end
    RUBY
  end

  test "leaves visibility alone when Active Support dispatch omits the method name" do
    assert_no_offense <<~RUBY
      class Container
        def process
          try
        end

        private
          class Worker
            def unused; end
          end
      end
    RUBY
  end

  test "leaves visibility alone when an Active Support dispatch name has invalid encoding" do
    assert_no_offense <<~'RUBY'
      class Container
        def process
          try("\xFF")
        end

        private
          class Worker
            def unused; end
          end
      end
    RUBY
  end

  test "keeps the visibility requested by public with an inline definition" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            public def status; end
          end
      end
    RUBY
  end

  test "an unrelated string literal does not hide an unused public method" do
    assert_offense <<~RUBY
      class Container
        LABEL = "unrelated"

        private
          class Worker
            def unused; end
          end
      end
    RUBY
  end

  test "an explicit self call may become private" do
    offenses = assert_offense <<~RUBY, count: 1
      class Container
        def process
          Worker.new.run
          nil
        end

        private
          class Worker
            def run
              self.status
              nil
            end

            def status; end
          end
      end
    RUBY

    assert_includes offenses.first.message, "status"
  end

  test "no offense when an instance is passed to another object" do
    assert_no_offense <<~RUBY
      class Backend
        def respond_to(command, with:)
          add_route(routes, Route.new(matcher: command, response: with))
        end

        private
          class Route < Data.define(:matcher, :response)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when an instance is assigned to a local" do
    assert_no_offense <<~RUBY
      class Backend
        def route_for(command)
          route = Route.new(matcher: command)
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when an instance is assigned through memoization" do
    assert_no_offense <<~RUBY
      class Backend
        def route_for(command)
          @route ||= Route.new(matcher: command)
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when a call chained from an instance is returned" do
    assert_no_offense <<~RUBY
      class Backend
        def route_for(command)
          Route.new(matcher: command).configure
        end

        private
          class Route < Data.define(:matcher)
            def configure
              self
            end

            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense for a method called through a qualified nested class in the same file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process; end
          end
      end

      Container::Worker.new.process
    RUBY
  end

  test "a safely navigated construction and call still mark the public method used" do
    offenses = assert_offense <<~RUBY, count: 1
      class Container
        def process
          Worker&.new&.used_method
          nil
        end

        private
          class Worker
            def used_method; end
            def unused_method; end
          end
      end
    RUBY

    assert_includes offenses.first.message, "unused_method"
  end

  test "an instance passed to a safely navigated call may escape the file" do
    assert_no_offense <<~RUBY
      class Container
        def process
          registry&.add(Worker.new)
        end

        private
          class Worker
            def externally_used; end
          end
      end
    RUBY
  end

  test "an instance published by its own method may escape the file" do
    assert_no_offense <<~RUBY
      class Container
        def process
          Worker.new.publish
          nil
        end

        private
          class Worker
            def publish
              $worker = self
            end

            def externally_used; end
          end
      end
    RUBY
  end

  test "a nested class stored in its own constant may escape the file" do
    assert_no_offense <<~RUBY
      class Container
        def worker_type
          Worker::SELF
        end

        private
          class Worker
            SELF = self

            def externally_used; end
          end
      end
    RUBY
  end

  test "registers an offense without crashing when a standalone construction closes the file" do
    assert_offense <<~RUBY
      class Container
        private
          class Worker
            def unused_method; end
          end
      end

      Container::Worker.new
    RUBY
  end

  test "no offense when an instance is collected" do
    assert_no_offense <<~RUBY
      class Backend
        def routes
          [ Route.new(matcher: nil) ]
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense for a method reached through a delegate outside the class" do
    assert_no_offense <<~RUBY
      class Backend
        def match(command)
          Router.new(command).matches?
        end

        private
          class Router
            delegate :matches?, to: :route
          end

          class Route
            def matches?
              true
            end
          end
      end
    RUBY
  end

  test "no offense when an instance is yielded" do
    assert_no_offense <<~RUBY
      class Backend
        def each_route
          yield Route.new(matcher: nil)
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when a method hands back the instance it built" do
    assert_no_offense <<~RUBY
      class Backend
        def route_for(command)
          Route.new(matcher: command)
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when a method hands back an allocated instance" do
    assert_no_offense <<~RUBY
      class Backend
        def worker
          Worker.allocate
        end

        private
          class Worker
            def perform; end
          end
      end
    RUBY
  end

  test "no offense when an instance is yielded from a branch" do
    assert_no_offense <<~RUBY
      class Backend
        def each_route(command)
          yield command ? Route.new(matcher: command) : fallback
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense when an instance is returned" do
    assert_no_offense <<~RUBY
      class Backend
        def route_for(command)
          return Route.new(matcher: command) if command

          nil
        end

        private
          class Route < Data.define(:matcher)
            def matches?(command)
              matcher.call(command)
            end
          end
      end
    RUBY
  end

  test "no offense for a protocol method Ruby calls structurally" do
    assert_no_offense <<~RUBY
      class Customer
        def checkout
          PreferenceAttributes.new(options).items
        end

        private
          class PreferenceAttributes < Data.define(:options)
            def items
              options[:items]
            end

            def to_hash
              { items: items }
            end
          end
      end
    RUBY
  end

  test "no offense for public Psych protocol methods" do
    assert_no_offense <<~RUBY
      class Container
        def dump
          Worker.new.dump
          nil
        end

        private
          class Worker
            def dump = to_yaml
            def encode_with(coder) = coder["value"] = 1
            def init_with(coder) = (@value = coder["value"])
          end
      end
    RUBY
  end

  test "no offense when an instance is double-splatted into a call" do
    assert_no_offense <<~RUBY
      class Customer
        def charge(amount)
          client.create(**PaymentAttributes.new(amount))
        end

        private
          class PaymentAttributes < Data.define(:amount)
            def to_hash
              { amount: amount }
            end
          end
      end
    RUBY
  end

  test "registers offense when instances are built and used on the spot" do
    offenses = assert_offense <<~RUBY, count: 1
      class Sequencer
        def run
          Node.new(name).connect
          nil
        end

      private
        class Node
          def initialize(name)
            @name = name
          end

          def connect
          end

            def capture_sequence
            end
          end
      end
    RUBY

    assert_includes offenses.first.message, "capture_sequence"
  end

  test "follows a carried value deeper than Ruby's call stack" do
    construction = RuboCop::AST::SendNode.new(:send, [ RuboCop::AST::Node.new(:const, [ nil, :Worker ]), :new ])
    outermost = 5_000.times.reduce(construction) do |receiver, _|
      RuboCop::AST::SendNode.new(:send, [ receiver, :itself ])
    end
    carried = RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinement::CarriedValue

    assert_same outermost, carried.new(construction).outermost
  end
end
