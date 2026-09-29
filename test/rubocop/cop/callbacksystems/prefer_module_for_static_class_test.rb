require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferModuleForStaticClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferModuleForStaticClass
  self.project_indexed = true

  test "registers offense for a singleton section with a private part" do
    offenses = assert_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            normalize(reports)
          end

          private
            def normalize(raw)
              raw.downcase
            end
        end
      end
    RUBY

    assert_includes offenses.first.message, "extend self"
  end

  test "allows a static class extended with another module" do
    assert_no_offense <<~RUBY
      class Architecture
        extend Comparable

        NAMES = { "arm64" => "arm64" }

        class << self
          def resolve(raw)
            normalize(raw)
          end

          private
            def normalize(raw)
              NAMES.fetch(raw)
            end
        end
      end
    RUBY
  end

  test "allows an extension whose callback observes the class object" do
    assert_no_offense <<~RUBY
      REGISTRY = []

      module Registrar
        def self.extended(base)
          REGISTRY << base
        end
      end

      class Architecture
        extend Registrar

        class << self
          private
            def normalize(value) = value.to_s
        end
      end
    RUBY
  end

  test "reuses the project class uses across candidates" do
    assert_offense <<~RUBY, count: 2
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      class Platform
        class << self
          def resolve(name); end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "refreshes reference locations after the indexed source changes" do
    source = <<~RUBY
      class Architecture
        class << self
          def resolve; end

          private
            def normalize; end
        end
      end
      Architecture.resolve
    RUBY
    project_index = project_index_for(DEFAULT_FILE => source)
    revisions = CopSourceRevisions.new(self.class.cop_class, file: project.path_of(DEFAULT_FILE), project_index:)

    assert_equal 1, revisions.offense_count
    revisions.update("\n#{source}")

    assert_equal 1, revisions.offense_count
  end

  test "registers an offense when the candidate reads an unresolved constant" do
    assert_offense <<~RUBY
      class Architecture
        class << self
          def resolve
            MissingConstant
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a class under a dynamic namespace the index cannot resolve" do
    assert_no_offense <<~RUBY
      class namespace::Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "does not infer project usage without the project index" do
    assert_no_offense <<~RUBY, project_sources: false
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class constructed in another file" do
    external_source = <<~RUBY
      Architecture.new
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb", project_sources: { "lib/report.rb" => external_source }
  end

  test "allows a static class whose type is inspected" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      Architecture.is_a?(Class)
    RUBY
  end

  test "allows a static class compared with Class" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      Class === Architecture
    RUBY
  end

  test "allows a static class matched against Class" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      case Architecture
      when Class
        true
      end
    RUBY
  end

  test "allows a static class with a descendant in another file" do
    external_source = <<~RUBY
      class CustomArchitecture < Architecture
      end
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb",
      project_sources: { "lib/custom_architecture.rb" => external_source }
  end

  test "allows a static class reopened in another file" do
    external_source = <<~RUBY
      class Architecture
      end
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb",
      project_sources: { "lib/architecture_extension.rb" => external_source }
  end

  test "allows a static class reopened in the same file" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      class Architecture
      end
    RUBY
  end

  test "allows a static class that may be an unresolved parent in another file" do
    external_source = <<~RUBY
      parent = Architecture

      class CustomArchitecture < parent
      end
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb",
      project_sources: { "lib/custom_architecture.rb" => external_source }
  end

  test "registers an offense when another file only calls a class method" do
    external_source = <<~RUBY
      Architecture.resolve([])
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_offense source, file: "lib/architecture.rb", project_sources: { "lib/report.rb" => external_source }
  end

  test "does not infer convertibility while any indexed ancestry is dynamic" do
    external_source = <<~RUBY
      class Report < report_parent
      end
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb", project_sources: { "lib/report.rb" => external_source }
  end

  test "allows a static class passed to another object" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      registry.register(Architecture)
    RUBY
  end

  test "allows a static class kept under a local alias" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      klass = Architecture
      klass.new
    RUBY
  end

  test "allows a static class yielded through then" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end

      Architecture.then { it.new }
    RUBY
  end

  test "registers an offense when another file only reads a namespaced constant" do
    external_source = <<~RUBY
      Architecture::NAMES
    RUBY
    source = <<~RUBY
      class Architecture
        NAMES = [ "arm64" ]

        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_offense source, file: "lib/architecture.rb", project_sources: { "lib/report.rb" => external_source }
  end

  test "allows a static class used to access an unresolved namespaced constant" do
    external_source = <<~RUBY
      Architecture::Missing
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb", project_sources: { "lib/report.rb" => external_source }
  end

  test "does not infer convertibility while any indexed file has a parse error" do
    assert_no_offense <<~RUBY, file: "lib/architecture.rb", project_sources: { "lib/broken.rb" => "class Broken\n" }
      class Architecture
        class << self
          def resolve(reports); end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "does not infer convertibility through ambiguous method visibility" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve; end

          private
            def normalize; end

          public ENV.fetch("METHOD", :resolve)
        end
      end
    RUBY
  end

  test "allows a static class that constructs an instance internally" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def build
            new
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that allocates an instance internally" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def build
            allocate
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class constructed in a block run from its singleton section" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          [ 1 ].each { new }

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class constructed in a deferred block" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          register { new }

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class allocated in a lambda" do
    assert_no_offense <<~RUBY
      class Architecture
        BUILDER = -> { allocate }

        class << self
          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that forwards construction as a method" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          tap(&:new)

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that aliases its constructor" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          alias_method :make, :new

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that aliases its constructor with keyword syntax" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          alias make new

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that undefines its constructor" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          undef new

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that constructs from its duplicate" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def build
            dup.new
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that returns itself implicitly" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def class_object
            itself
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that calls class-only introspection internally" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def parent
            superclass
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class whose singleton method calls super" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            super
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class that defines the inherited callback" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def inherited(subclass)
            registry << subclass
          end

          private
            def registry = (@registry ||= [])
        end
      end
    RUBY
  end

  test "allows a static class that calls the inherited hook" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def observe(subclass)
            inherited(subclass)
          end

          private
            def normalize(value) = value.to_s
        end
      end
    RUBY
  end

  test "allows a static class observed by its superclass inherited callback" do
    assert_no_offense <<~RUBY
      REGISTRY = []

      class << Object
        def inherited(subclass)
          REGISTRY << subclass
          super
        end
      end

      class Architecture
        class << self
          def resolve(value) = normalize(value)

          private
            def normalize(value) = value.to_s
        end
      end
    RUBY
  end

  test "allows a static class that invokes a method added to Class" do
    assert_no_offense <<~RUBY
      REGISTRY = []

      class Class
        def register
          REGISTRY << self
        end
      end

      class Architecture
        class << self
          def resolve(value)
            register
            normalize(value)
          end

          private
            def normalize(value) = value.to_s
        end
      end
    RUBY
  end

  test "allows a static class named in an unsafe serialized payload" do
    external_source = <<~RUBY
      YAML.unsafe_load("--- !ruby/object:Architecture {}")
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(value) = normalize(value)

          private
            def normalize(value) = value.to_s
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb", project_sources: { "lib/reader.rb" => external_source }
  end

  test "allows a static class that Marshal may instantiate" do
    external_source = <<~RUBY
      Marshal.load(File.binread("architecture.dump"))
    RUBY
    source = <<~RUBY
      class Architecture
        class << self
          def resolve(value) = normalize(value)

          private
            def normalize(value) = value.to_s
        end
      end
    RUBY

    assert_no_offense source, file: "lib/architecture.rb", project_sources: { "lib/reader.rb" => external_source }
  end

  test "allows a static class whose singleton self is observed" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def class_object
            self
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a static class whose singleton self is type-checked" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def class_object?
            self.is_a?(Class)
          end

          private
            def normalize(raw); end
        end
      end
    RUBY
  end

  test "allows a singleton section without a private part" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            reports.first
          end
        end
      end
    RUBY
  end

  test "allows a class with instance methods" do
    assert_no_offense <<~RUBY
      class Architecture
        def resolve
        end

        class << self
          def build
            new
          end

          private
            def default
            end
        end
      end
    RUBY
  end

  test "allows a class with a superclass" do
    assert_no_offense <<~RUBY
      class Architecture < Base
        class << self
          def resolve(reports)
            normalize(reports)
          end

          private
            def normalize(raw)
              raw
            end
        end
      end
    RUBY
  end

  test "allows a class whose private section holds instance state" do
    assert_no_offense <<~RUBY
      class Architecture
        class << self
          def resolve(reports)
            reports
          end
        end

        private
          attr_reader :name
      end
    RUBY
  end
end
