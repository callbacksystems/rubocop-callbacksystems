require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinementTest < CopTestCase
  include SourceParsing

  test "confined? accepts an instance consumed before the enclosing method returns" do
    assert confinement_of(<<~RUBY).confined?
      class Container
        def process
          Worker.new.run
          nil
        end

        class Worker
          def run; end
        end
      end
    RUBY
  end

  test "confined? accepts calls to methods owned by the nested class" do
    assert confinement_of(<<~RUBY).confined?
      class Container
        def process
          Worker.new.run
          nil
        end

        class Worker
          def run
            finish
          end

          def finish; end
        end
      end
    RUBY
  end

  test "confined? rejects an instance returned by the enclosing method" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        def worker
          Worker.new
        end

        class Worker
        end
      end
    RUBY
  end

  test "confined? rejects a class object passed as an argument" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
        end
      end

      registry.register(Container::Worker)
    RUBY
  end

  test "confined? rejects a bare class reference" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
        end
      end

      Container::Worker
    RUBY
  end

  test "confined? accepts a nested constant read" do
    assert confinement_of(<<~RUBY).confined?
      class Container
        def status
          Worker::STATUS
        end

        class Worker
          STATUS = :ready
        end
      end
    RUBY
  end

  test "confined? rejects a factory that returns a receiverless construction" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          def self.build
            new
          end
        end
      end
    RUBY
  end

  test "confined? rejects constructions expanded into arguments" do
    assert_not confinement_of(source_with("sink(*Worker.new)")).confined?
    assert_not confinement_of(source_with("sink(**Worker.new)")).confined?
    assert_not confinement_of(source_with("sink(&Worker.new)")).confined?
  end

  test "confined? rejects constructions handed to control flow" do
    assert_not confinement_of(source_with("super(Worker.new)")).confined?
    assert_not confinement_of(source_with("condition ? Worker.new : fallback")).confined?
    assert_not confinement_of(source_with("condition && Worker.new")).confined?
    assert_not confinement_of(source_with("condition || Worker.new")).confined?
  end

  test "confined? rejects constructions handed to loop exits" do
    assert_not confinement_of(source_with("break Worker.new")).confined?
    assert_not confinement_of(source_with("next Worker.new")).confined?
  end

  test "confined? rejects constructions held by case and rescue branches" do
    assert_not confinement_of(source_with("case condition; when true; Worker.new; end")).confined?
    assert_not confinement_of(source_with("begin; operation; rescue; Worker.new; end")).confined?
    assert_not confinement_of(source_with("begin; Worker.new; ensure; cleanup; end")).confined?
  end

  test "confined? rejects constructions retained by iteration patterns and ranges" do
    assert_not confinement_of(source_with("for worker in Worker.new; end")).confined?
    assert_not confinement_of(source_with("Worker.new => worker")).confined?
    assert_not confinement_of(source_with("Worker.new..other")).confined?
  end

  test "confined? rejects receiverless constructions in opaque class-body blocks" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          define_singleton_method(:build) { new }
        end
      end
    RUBY
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          class << self
            define_method(:build) { allocate }
          end
        end
      end
    RUBY
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          configure do
            new
            nil
          end
        end
      end
    RUBY
  end

  test "confined? rejects an instance that its own method publishes" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        def process
          Worker.new.publish
        end

        class Worker
          def publish
            $worker = self
          end
        end
      end
    RUBY
  end

  test "confined? rejects a class object stored in one of its constants" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        def worker_type
          Worker::SELF
        end

        class Worker
          SELF = self
        end
      end
    RUBY
  end

  test "confined? rejects a class object returned through enclosing class bodies" do
    assert_not confinement_of(<<~RUBY).confined?
      WORKER = class Container
        class Worker
          self
        end
      end
    RUBY
  end

  test "confined? rejects an implicit instance value that its own method publishes" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        def process
          Worker.new.publish
        end

        class Worker
          def publish
            $worker = itself
          end
        end
      end
    RUBY
  end

  test "confined? rejects an instance published by a dynamically defined method" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        def process
          Worker.new.publish
        end

        class Worker
          define_method(:publish) { $worker = self }
        end
      end
    RUBY
  end

  test "confined? rejects holders that retain an instance" do
    %w[ binding freeze method(:publish) to_enum ].each do |holder|
      assert_not confinement_of(<<~RUBY).confined?
        class Container
          def process
            Worker.new.publish
          end

          class Worker
            def publish
              #{holder}
            end
          end
        end
      RUBY
    end
  end

  test "confined? rejects superclasses and mixins" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker < BaseWorker
        end
      end
    RUBY
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          include WorkerCallbacks
        end
      end
    RUBY
  end

  test "confined? rejects a safe-navigation mixin call" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          self&.include WorkerCallbacks
        end
      end
    RUBY
  end

  test "confined? rejects an opaque class-body macro that may retain the class" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          register
        end
      end
    RUBY
  end

  test "confined? rejects a class object exposed from an opaque class-body block" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          configure do
            REGISTRY << self
          end
        end
      end
    RUBY
  end

  test "confined? accepts a built-in class-body primitive" do
    assert confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          attr_reader :value
        end
      end
    RUBY
  end

  test "confined? rejects a class-body primitive redefined to retain the class" do
    assert_not confinement_of(<<~RUBY).confined?
      class Class
        def attr_reader(*)
          REGISTRY << self
          super
        end
      end

      class Container
        class Worker
          attr_reader :value
        end
      end
    RUBY
  end

  test "confined? rejects a singleton callback that may publish the class" do
    assert_not confinement_of(<<~RUBY).confined?
      class Container
        class Worker
          def self.method_added(name)
            register(name)
          end

          def process; end
        end
      end
    RUBY
  end

  test "confined? rejects inherited dispatch that may publish an instance" do
    assert_not confinement_of(<<~RUBY).confined?
      class Object
        def publish
          REGISTRY << self
        end
      end

      class Container
        def process
          Worker.new.run
          nil
        end

        class Worker
          def run
            publish
          end
        end
      end
    RUBY
  end

  test "source constants are indexed once per source tree" do
    source_constants = RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinement::SourceConstants
    root = processed_source("class Container; Worker.new; end").ast

    assert_same source_constants.for(root, uri: "file:///container.rb"),
      source_constants.for(root, uri: "file:///container.rb")
    assert_not_same source_constants.for(root, uri: "file:///container.rb"),
      source_constants.for(processed_source("Worker.new").ast, uri: "file:///container.rb")
    assert_not_same source_constants.for(root, uri: "file:///container.rb"),
      source_constants.for(root, uri: "file:///other.rb")
  end

  private
    def confinement_of(source)
      project_index = project_index_for("lib/container.rb" => source)
      nested_class = processed_source(source).ast.each_node(:class).find { it.identifier.short_name == :Worker }
      declaration = project_index["Container::Worker"]

      RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinement.new(nested_class, declaration:, project_index:)
    end

    def source_with(expression)
      <<~RUBY
        class Container
          def process(condition = nil)
            loop do
              #{expression}
            end
          end

          class Worker
          end
        end
      RUBY
    end
end
