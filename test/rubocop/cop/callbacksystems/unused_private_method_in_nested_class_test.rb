require "test_helper"

class UnusedPrivateMethodInNestedClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::UnusedPrivateMethodInNestedClass
  self.project_indexed = true

  test "registers offense for unused private method in private nested class" do
    offenses = assert_offense <<~RUBY, count: 1, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
          nil
        end

        private
          class Bar
            def run
              helper
            end

            private
              def helper; end
              def unused; end
          end
      end
    RUBY

    assert_includes offenses.first.message, "unused"
  end

  test "no offense when all private methods are called" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
          nil
        end

        private
          class Bar
            def run
              helper
              other_helper
            end

            private
              def helper; end
              def other_helper; end
          end
      end
    RUBY
  end

  test "no offense for nested class not in private section" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        class Bar
          def run; end

          private
            def unused; end
        end

        def process
          Bar.new.run
        end
      end
    RUBY
  end

  test "no offense when private method is referenced by callback" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            after_initialize :setup

            def run; end

            private
              def setup; end
          end
      end
    RUBY
  end

  test "no offense when private method is referenced by a before update callback" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        private
          class Bar
            before_update :normalize

            private
              def normalize; end
          end
      end
    RUBY
  end

  test "no offense when a private method name is passed to an unknown DSL" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            on_event :prepare

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "no offense when an interpolated DSL name may call the private method" do
    assert_no_offense <<~'RUBY'
      class Container
        private
          class Worker
            on_event :"prepare_#{event}"

            private
              def prepare_event; end
          end
      end
    RUBY
  end

  test "no offense for public methods in private nested class" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
        end

        private
          class Bar
            def run; end
            def unused_but_public; end
          end
      end
    RUBY
  end

  test "detects multiple unused private methods" do
    assert_offense <<~RUBY, count: 2, file: "app/models/foo.rb"
      class Foo
        def process
          Bar.new.run
          nil
        end

        private
          class Bar
            def run; end

            private
              def unused_one; end
              def unused_two; end
          end
      end
    RUBY
  end

  test "works in modules" do
    assert_offense <<~RUBY, count: 1, file: "app/models/foo.rb"
      module Foo
        def process
          Bar.new.run
          nil
        end

        private
          class Bar
            def run; end

            private
              def unused; end
          end
      end
    RUBY
  end

  test "does not infer project confinement without the project index" do
    assert_no_offense <<~RUBY, project_sources: false
      class Container
        private
          class Worker
            private
              def unused; end
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
            private
              def unused; end
          end
      end
    RUBY
  end

  test "keeps methods when dynamic visibility may make them public" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            public ENV.fetch("PUBLIC_METHOD")

            private
              def unused; end
          end
      end
    RUBY
  end

  test "keeps private methods when an instance is handed back" do
    assert_no_offense <<~RUBY
      class Container
        def worker
          Worker.new
        end

        private
          class Worker
            private
              def externally_used; end
          end
      end
    RUBY
  end

  test "keeps private methods when an instance publishes itself" do
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

            private
              def externally_used; end
          end
      end
    RUBY
  end

  test "keeps private methods when the class object is handed off" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def externally_used; end
          end
      end

      Class.new(Container::Worker)
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
            private
              def externally_used; end
          end
      end
    RUBY
  end

  test "keeps private methods when a mixin can invoke them" do
    assert_no_offense <<~RUBY
      module WorkerCallbacks
        def run
          prepare
        end
      end

      class Container
        private
          class Worker
            include WorkerCallbacks

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps private methods when another file reaches the visually private class" do
    external_source = <<~RUBY
      Container::Worker.new.send(:prepare)
    RUBY
    source = <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
          end
      end
    RUBY

    assert_no_offense source, file: "app/models/container.rb",
      project_sources: { "app/jobs/process_worker_job.rb" => external_source }
  end

  test "keeps private methods when another file reopens the visually private class" do
    external_source = <<~RUBY
      class Container::Worker
      end
    RUBY
    source = <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
          end
      end
    RUBY

    assert_no_offense source, file: "app/models/container.rb",
      project_sources: { "app/models/container/worker.rb" => external_source }
  end

  test "keeps private methods when the visually private class is reopened in the same file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
          end
      end

      class Container::Worker
      end
    RUBY
  end

  test "allows a private method in a nested class with a superclass" do
    assert_no_offense <<~RUBY
      class LoggerTest
        private
          class LoggerProbe < BaseLogger
            private
              def on_start(payload)
                events << payload
              end
          end
      end
    RUBY
  end

  test "allows hooks when the nested class is subclassed elsewhere in the same file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def around_process; end
          end
      end

      class SpecializedWorker < Container::Worker
      end
    RUBY
  end

  test "allows hooks when the nested class may have a dynamic subclass in the same file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def around_process; end
          end
      end

      parent = Container::Worker

      class SpecializedWorker < parent
      end
    RUBY
  end

  test "allows structural private methods Ruby calls implicitly" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def method_missing(name, ...); end
              def respond_to_missing?(name, private_methods = false); end
          end
      end
    RUBY
  end

  test "allows every private hook the RuboCop runtime list treats as implicit" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def marshal_dump; end
              def coerce(other); end
              def inherited(subclass); end
              def const_missing(name); end
              def singleton_method_added(name); end
              def encode_with(coder); end
              def init_with(coder); end
          end
      end
    RUBY
  end

  test "allows a private override inherited from an ancestor" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def to_s; end
          end
      end
    RUBY
  end

  test "allows a private method called dynamically by symbol" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process
              send(:prepare)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method called dynamically by string" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process
              send("prepare")
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps a private method invoked through a method object elsewhere in the file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
          end
      end

      Container::Worker.new.method(:prepare).call
      nil
    RUBY
  end

  test "keeps a private method inspected elsewhere in the file" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
          end
      end

      Container::Worker.new.respond_to?(:prepare, true)
      nil
    RUBY
  end

  test "keeps methods when invalidly encoded dispatch cannot prove confinement" do
    assert_no_offense <<~'RUBY'
      class Container
        private
          class Worker
            def process
              send("\xFF")
              nil
            end

            private
              def unused; end
          end
      end
    RUBY
  end

  test "ignores an invalidly encoded interpolation prefix without crashing" do
    assert_offense <<~'RUBY'
      class Container
        private
          class Worker
            def process(event)
              "\xFF#{event}"
            end

            private
              def unused; end
          end
      end
    RUBY
  end

  test "allows a private method called through self" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process
              self.prepare
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method called through safely navigated self" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process
              self&.prepare
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps a private method called on a receiver whose type is unknown" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process(other)
              other.prepare
              nil
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method converted to a method object" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def callback
              method(:prepare)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method converted to an unbound method object" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            CALLBACK = instance_method(:prepare)

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method inspected through respond to with private visibility" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def prepared?
              respond_to?(:prepare, true)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps private methods when their names are enumerated" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def callbacks
              private_methods(false)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method referenced by the alias keyword" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
              alias ready prepare
          end
      end
    RUBY
  end

  test "does not treat a global-variable alias as a private method reference" do
    assert_offense <<~RUBY
      class Container
        private
          class Worker
            alias $worker_error $ERROR_INFO

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "allows a private method referenced by alias method" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            private
              def prepare; end
              alias_method :ready, :prepare
          end
      end
    RUBY
  end

  test "keeps private methods when a dynamic method name cannot be resolved" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process(method_name)
              send(method_name)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps private methods when a safely navigated dynamic name cannot be resolved" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process(method_name)
              self&.send(method_name)
            end

            private
              def prepare; end
          end
      end
    RUBY
  end

  test "keeps methods when receiverless dispatch cannot prove confinement" do
    assert_no_offense <<~RUBY
      class Container
        private
          class Worker
            def process
              send
              nil
            end

            private
              def unused; end
          end
      end
    RUBY
  end

  test "reports through a dynamically called name with invalid encoding" do
    assert_offense <<~'RUBY'
      class Container
        def introspect(record)
          record.respond_to?("\xFF")
        end

        private
          class Worker
            private
              def unused; end
          end
      end
    RUBY
  end

  test "an unrelated symbol literal does not hide an unused private method" do
    assert_offense <<~RUBY
      class Container
        MARKER = :other

        private
          class Worker
            private
              def unused; end
          end
      end
    RUBY
  end

  test "adjacent string literals do not become a dynamic method prefix" do
    assert_offense <<~RUBY
      class Container
        MARKER = "pre" "fix"

        private
          class Worker
            private
              def unused; end
          end
      end
    RUBY
  end

  test "an interpolation before the text does not become a method prefix" do
    assert_offense <<~'RUBY'
      class Container
        MARKER = "#{event}_prepare"

        private
          class Worker
            private
              def unused; end
          end
      end
    RUBY
  end

  test "keeps methods when a dynamic lookup elsewhere makes file references incomplete" do
    assert_no_offense <<~RUBY
      class Container
        def introspect(record, method_name)
          record.respond_to?(method_name)
        end

        private
          class Worker
            private
              def unused; end
          end
      end
    RUBY
  end
end
