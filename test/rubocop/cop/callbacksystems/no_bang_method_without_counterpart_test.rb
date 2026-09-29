require "test_helper"

class RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpartTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpart
  self.project_indexed = true

  test "registers offense for bang method without counterpart" do
    assert_offense <<~RUBY
      class Example
        def process!
        end
      end
    RUBY
  end

  test "allows bang method with non-bang counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def save
        end

        def save!
        end
      end
    RUBY
  end

  test "allows non-bang methods" do
    assert_no_offense <<~RUBY
      class Example
        def process
        end

        def validate
        end
      end
    RUBY
  end

  test "does not treat the unary not operator as a conventional bang method" do
    assert_no_offense <<~RUBY
      class Example
        def !
          false
        end
      end
    RUBY
  end

  test "allows bang method when counterpart is defined after" do
    assert_no_offense <<~RUBY
      class Example
        def save!
        end

        def save
        end
      end
    RUBY
  end

  test "registers offense for multiple bang methods without counterparts" do
    assert_offense <<~RUBY, count: 2
      class Example
        def process!
        end

        def validate!
        end
      end
    RUBY
  end

  test "checks class methods too" do
    assert_offense <<~RUBY
      class Example
        def self.build!
        end
      end
    RUBY
  end

  test "allows class method bang with counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def self.build
        end

        def self.build!
        end
      end
    RUBY
  end

  test "works in modules" do
    assert_offense <<~RUBY
      module Example
        def process!
        end
      end
    RUBY
  end

  test "allows bang in module with counterpart" do
    assert_no_offense <<~RUBY
      module Example
        def process
        end

        def process!
        end
      end
    RUBY
  end

  test "handles private methods" do
    assert_no_offense <<~RUBY
      class Example
        def save
        end

        private
          def save!
          end
      end
    RUBY
  end

  test "handles empty class" do
    assert_no_offense <<~RUBY
      class Example
      end
    RUBY
  end

  test "handles class with only non-bang methods" do
    assert_no_offense <<~RUBY
      class Example
        def foo
        end

        def bar
        end
      end
    RUBY
  end

  test "does not consider counterpart from nested class" do
    assert_offense <<~RUBY
      class Outer
        def save!
        end

        private
          class Inner
            def save
            end
          end
      end
    RUBY
  end

  test "does not consider counterpart from outer class" do
    assert_offense <<~RUBY
      class Outer
        def save
        end

        private
          class Inner
            def save!
            end
          end
      end
    RUBY
  end

  test "does not combine nested classes with the same short name under different owners" do
    assert_offense <<~RUBY
      class First
        class Record
          def save
          end
        end
      end

      class Second
        class Record
          def save!
          end
        end
      end
    RUBY
  end

  test "each nested class is analyzed independently" do
    assert_offense <<~RUBY, count: 2
      class Outer
        def process!
        end

        private
          class Inner
            def validate!
            end
          end
      end
    RUBY
  end

  test "allows bang method in nested class when counterpart exists in same nested class" do
    assert_no_offense <<~RUBY
      class Outer
        private
          class Inner
            def save
            end

            def save!
            end
          end
      end
    RUBY
  end

  test "nested class bang methods are independent from outer class" do
    assert_no_offense <<~RUBY
      class Outer
        def save
        end

        def save!
        end

        private
          class Inner
            def process
            end

            def process!
            end
          end
      end
    RUBY
  end
  test "does not take an instance method as the counterpart of a singleton bang" do
    assert_offense <<~RUBY
      class Example
        def self.save!
        end

        def save
        end
      end
    RUBY
  end

  test "does not take a singleton method as the counterpart of an instance bang" do
    assert_offense <<~RUBY
      class Example
        def save!
        end

        def self.save
        end
      end
    RUBY
  end

  test "abstains when define_method may add an instance counterpart" do
    assert_no_offense <<~RUBY
      class Example
        define_method(:save) do
        end

        def save!
        end
      end
    RUBY
  end

  test "abstains from the instance domain when define_method has a dynamic name" do
    assert_no_offense <<~RUBY
      class Example
        define_method(method_name) do
        end

        def save!
        end
      end
    RUBY
  end

  test "abstains from the whole class when define_method makes ownership dynamic" do
    assert_no_offense <<~RUBY
      class Example
        define_method(method_name) do
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when define_singleton_method may add a singleton counterpart" do
    assert_no_offense <<~RUBY
      class Example
        define_singleton_method(:save) do
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains from the singleton domain when define_singleton_method has a dynamic name" do
    assert_no_offense <<~RUBY
      class Example
        define_singleton_method(method_name) do
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains from the whole class when define_singleton_method has a dynamic name" do
    assert_no_offense <<~RUBY
      class Example
        define_singleton_method(method_name) do
        end

        def save!
        end
      end
    RUBY
  end

  test "abstains when define_method runs in a singleton section" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          define_method(:save) do
          end

          def save!
          end
        end
      end
    RUBY
  end

  test "abstains conservatively from other domains around define_singleton_method" do
    assert_no_offense <<~RUBY
      class Example
        define_singleton_method(:save) do
        end

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with an attr_reader counterpart" do
    assert_no_offense <<~RUBY
      class Example
        attr_reader :save

        def save!
        end
      end
    RUBY
  end

  test "does not let an unrelated attr_reader hide an orphan bang" do
    assert_offense <<~RUBY
      class Example
        attr_reader :status

        def save!
        end
      end
    RUBY
  end

  test "does not take an attr_writer as a reader counterpart" do
    assert_offense <<~RUBY
      class Example
        attr_writer :save

        def save!
        end
      end
    RUBY
  end

  test "abstains when an accessor has a dynamic name" do
    assert_no_offense <<~RUBY
      class Example
        attr_accessor METHOD_NAME

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a keyword alias counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def persist
        end

        alias save persist

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with an alias_method counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def persist
        end

        alias_method :save, :persist

        def save!
        end
      end
    RUBY
  end

  test "does not let an unrelated alias_method hide an orphan bang" do
    assert_offense <<~RUBY
      class Example
        alias_method :persist, :save

        def publish!
        end
      end
    RUBY
  end

  test "abstains when alias_method has a dynamic target name" do
    assert_no_offense <<~RUBY
      class Example
        alias_method target_name, :persist

        def save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with a module_function counterpart" do
    assert_no_offense <<~RUBY
      module Example
        def save
        end

        module_function :save

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when module_function has a dynamic target name" do
    assert_no_offense <<~RUBY
      module Example
        module_function method_name

        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang after the no-argument module_function form" do
    assert_no_offense <<~RUBY
      module Example
        module_function

        def save
        end

        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang whose counterpart sits in a singleton class body" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          def save
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang whose counterpart a class_methods block adds" do
    assert_no_offense <<~RUBY
      module Example
        class_methods do
          def save
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when a class_methods block generates methods" do
    assert_no_offense <<~RUBY
      module Example
        class_methods do
          define_method(:save) do
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "does not take a class_methods definition as an instance counterpart" do
    assert_offense <<~RUBY
      module Example
        class_methods do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang whose counterpart an included block adds" do
    assert_no_offense <<~RUBY
      module Example
        included do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "abstains when an included block generates methods" do
    assert_no_offense <<~RUBY
      module Example
        included do
          define_method(:save) do
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang whose prepended block adds the counterpart" do
    assert_no_offense <<~RUBY
      module Example
        prepended do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang whose class_eval block adds the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        class_eval do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "allows a singleton bang whose instance_eval block adds the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        instance_eval do
          def save
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when an opaque block may install a counterpart" do
    assert_no_offense <<~RUBY
      class Example
        installs_methods do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "abstains when delegate may define the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        delegate :save, to: :record

        def save!
        end
      end
    RUBY
  end

  test "does not let an unrelated delegate hide an orphan bang" do
    assert_offense <<~RUBY
      class Example
        delegate :status, to: :record

        def save!
        end
      end
    RUBY
  end

  test "abstains when delegate_missing_to provides dynamic dispatch" do
    assert_no_offense <<~RUBY
      class Example
        delegate_missing_to :record

        def save!
        end
      end
    RUBY
  end

  test "abstains when Forwardable may define the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def_delegator :record, :save

        def save!
        end
      end
    RUBY
  end

  test "abstains when a scope may define the singleton counterpart" do
    assert_no_offense <<~RUBY
      class Example
        scope :save, -> { all }

        def self.save!
        end
      end
    RUBY
  end

  test "does not let an unrelated scope hide an orphan singleton bang" do
    assert_offense <<~RUBY
      class Example
        scope :published, -> { all }

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when an unknown declarative macro names the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        custom_macro :save

        def save!
        end
      end
    RUBY
  end

  test "does not let an unrelated declarative macro hide an orphan bang" do
    assert_offense <<~RUBY
      class Example
        custom_macro :status

        def save!
        end
      end
    RUBY
  end

  test "abstains when an unknown declarative macro receives a dynamic name" do
    assert_no_offense <<~RUBY
      class Example
        custom_macro METHOD_NAME

        def save!
        end
      end
    RUBY
  end

  test "does not take an included definition as a singleton counterpart" do
    assert_offense <<~RUBY
      module Example
        included do
          def save
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "allows an instance bang whose counterpart an it-parameter included block adds" do
    assert_no_offense <<~RUBY
      module Example
        included do
          it.registered!

          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "reports a bang inside a singleton class body with no counterpart there" do
    assert_offense <<~RUBY
      class Example
        class << self
          def save!
          end
        end
      end
    RUBY
  end

  test "allows an instance bang with a counterpart inherited in the same file" do
    assert_no_offense <<~RUBY
      class Base
        def save
        end
      end

      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a counterpart inherited from another file" do
    project_sources = { "app/models/base.rb" => "class Base; def save; end; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "abstains when an externally defined ancestor has no indexed counterpart" do
    project_sources = { "app/models/base.rb" => "class Base; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "abstains when an external ancestor may generate the counterpart" do
    project_sources = { "app/models/base.rb" => "class Base; define_method(:save) {}; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a counterpart mixed in from another file" do
    project_sources = { "app/models/persistence.rb" => "module Persistence; def save; end; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        include Persistence

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a prepended counterpart" do
    assert_no_offense <<~RUBY
      module Persistence
        def save
        end
      end

      class Example
        prepend Persistence

        def save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a counterpart inherited through a constant alias" do
    assert_no_offense <<~RUBY
      class Base
        def save
        end
      end

      Parent = Base

      class Specialized < Parent
        def save!
        end
      end
    RUBY
  end

  test "abstains when the superclass has a runtime namespace" do
    assert_no_offense <<~RUBY
      class Specialized < registry::Base
        def save!
        end
      end
    RUBY
  end

  test "abstains when an ancestor in another file has a runtime superclass" do
    project_sources = { "app/models/base.rb" => "class Base < registry::Record; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "abstains when an unrelated indexed document has dynamic ancestry" do
    project_sources = { "app/models/other.rb" => "class Other < registry::Record; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "abstains when the superclass cannot be resolved" do
    assert_no_offense <<~RUBY
      class Specialized < Missing
        def save!
        end
      end
    RUBY
  end

  test "abstains when any indexed project document has a parse error" do
    project_sources = { "app/models/broken.rb" => "class Broken\n" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "abstains when a mixin has a runtime namespace" do
    assert_no_offense <<~RUBY
      class Specialized
        include registry.mixin

        def save!
        end
      end
    RUBY
  end

  test "abstains when a mixin cannot be resolved" do
    assert_no_offense <<~RUBY
      class Specialized
        include Missing

        def save!
        end
      end
    RUBY
  end

  test "abstains from a class whose name has a runtime namespace" do
    assert_no_offense <<~RUBY
      class registry::Specialized
        def save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with a counterpart inherited in the same file" do
    assert_no_offense <<~RUBY
      class Base
        def self.save
        end
      end

      class Specialized < Base
        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with a counterpart inherited from another file" do
    project_sources = { "app/models/base.rb" => "class Base; def self.save; end; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Specialized < Base
        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with an extended counterpart" do
    assert_no_offense <<~RUBY
      module Persistence
        def save
        end
      end

      class Example
        extend Persistence

        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with a class_methods counterpart mixed in from another file" do
    project_sources = {
      "app/models/persistence.rb" => <<~CONCERN
        module Persistence
          class_methods do
            def save
            end
          end
        end
      CONCERN
    }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        include Persistence

        def self.save!
        end
      end
    RUBY
  end

  test "allows a counterpart inherited into a nested singleton class" do
    assert_no_offense <<~RUBY
      class Base
        class << self
          class << self
            def save
            end
          end
        end
      end

      class Specialized < Base
        class << self
          class << self
            def save!
            end
          end
        end
      end
    RUBY
  end

  test "reports a bang without a counterpart in a nested singleton class" do
    assert_offense <<~RUBY
      class Example
        class << self
          class << self
            def save!
            end
          end
        end
      end
    RUBY
  end

  test "allows a singleton bang with a class_methods counterpart inherited in the same file" do
    assert_no_offense <<~RUBY
      class Base
        class_methods do
          def save
          end
        end
      end

      class Specialized < Base
        def self.save!
        end
      end
    RUBY
  end

  test "allows a singleton bang with a singleton-section counterpart inherited in the same file" do
    assert_no_offense <<~RUBY
      class Base
        class << self
          def save
          end
        end
      end

      class Specialized < Base
        def self.save!
        end
      end
    RUBY
  end

  test "allows an instance bang with a transitively inherited counterpart in the same file" do
    assert_no_offense <<~RUBY
      class Grandparent
        def save
        end
      end

      class Parent < Grandparent
      end

      class Child < Parent
        def save!
        end
      end
    RUBY
  end

  test "resolves transitive inheritance within a lexical namespace" do
    assert_no_offense <<~RUBY
      module Outer
        class Grandparent
          def save
          end
        end

        class Parent < Grandparent
        end

        class Child < Parent
          def save!
          end
        end
      end
    RUBY
  end

  test "reports through a cyclic same-file inheritance graph without recursing forever" do
    assert_offense <<~RUBY
      class First < Second
        def save!
        end
      end

      class Second < First
      end
    RUBY
  end

  test "allows a singleton bang with a transitively inherited counterpart in the same file" do
    assert_no_offense <<~RUBY
      class Grandparent
        def self.save
        end
      end

      class Parent < Grandparent
      end

      class Child < Parent
        def self.save!
        end
      end
    RUBY
  end

  test "abstains when an instance ancestor handles missing methods" do
    assert_no_offense <<~RUBY
      class Base
        def method_missing(name, ...)
        end
      end

      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "does not use instance method_missing for a singleton bang" do
    assert_offense <<~RUBY
      class Example
        def method_missing(name, ...)
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when an instance ancestor advertises missing methods" do
    assert_no_offense <<~RUBY
      class Base
        def respond_to_missing?(name, include_private)
        end
      end

      class Specialized < Base
        def save!
        end
      end
    RUBY
  end

  test "abstains when the singleton ancestry handles missing methods" do
    assert_no_offense <<~RUBY
      class Base
        def self.method_missing(name, ...)
        end
      end

      class Specialized < Base
        def self.save!
        end
      end
    RUBY
  end

  test "does not use singleton method_missing for an instance bang" do
    assert_offense <<~RUBY
      class Example
        def self.method_missing(name, ...)
        end

        def save!
        end
      end
    RUBY
  end

  test "follows an inheritance chain deeper than Ruby's call stack" do
    classes = [ "class Ancestor; def save; end; end" ]
    1.upto(2_000) { classes << "class Descendant#{it} < #{it == 1 ? "Ancestor" : "Descendant#{it.pred}"}; end" }
    classes << "class Last < Descendant2000; def save!; end; end"

    assert_no_offense "#{classes.join("\n")}\n"
  end

  test "finds a counterpart in a later reopening" do
    assert_no_offense <<~RUBY
      class Example
        def save!
        end
      end

      class Example
        def save
        end
      end
    RUBY
  end

  test "finds a counterpart in a reopening from another file" do
    project_sources = { "app/models/example_extension.rb" => "class Example; def save; end; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "abstains when another file reopens the namespace without an indexed counterpart" do
    project_sources = { "app/models/example_extension.rb" => "class Example; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "reports when no project file defines a counterpart" do
    project_sources = { "app/models/unrelated.rb" => "class Unrelated; def save; end; end" }

    assert_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "finds counterparts in every singleton section" do
    assert_no_offense <<~RUBY
      class Example
        class << self
          def unrelated
          end
        end

        class << self
          def save
          end

          def save!
          end
        end
      end
    RUBY
  end

  test "finds counterparts in every included block" do
    assert_no_offense <<~RUBY
      module Example
        included do
          def unrelated
          end
        end

        included do
          def save
          end
        end

        def save!
        end
      end
    RUBY
  end

  test "finds counterparts in every class methods block" do
    assert_no_offense <<~RUBY
      module Example
        class_methods do
          def unrelated
          end
        end

        class_methods do
          def save
          end
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains from singleton classes for expressions" do
    assert_no_offense <<~RUBY
      class Example
        class << FIRST
          def save
          end
        end

        class << SECOND
          def save!
          end
        end
      end
    RUBY
  end

  test "allows a counterpart in another singleton class for the same expression" do
    assert_no_offense <<~RUBY
      class Other
      end

      class Example
        class << Other
          def save
          end
        end

        class << Other
          def save!
          end
        end
      end
    RUBY
  end

  test "does not use a definition on a known other receiver as a singleton counterpart" do
    assert_offense <<~RUBY
      class Other
      end

      class Example
        def Other.save
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains when a dynamic singleton definition may provide the counterpart" do
    assert_no_offense <<~RUBY
      class Example
        def receiver.save
        end

        def self.save!
        end
      end
    RUBY
  end

  test "abstains from singleton absence after a dynamic definition in another document" do
    project_sources = { "app/models/extension.rb" => "target = Object.const_get(:Example); def target.save; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def self.save!
        end
      end
    RUBY
  end

  test "abstains when reflection in another document may define the counterpart" do
    project_sources = {
      "app/models/extension.rb" => <<~RUBY
        target = Object.const_get(:Example)
        target.define_singleton_method(:save) do
        end
      RUBY
    }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def self.save!
        end
      end
    RUBY
  end

  test "abstains when another document resolves constants reflectively" do
    project_sources = { "app/models/extension.rb" => "Object.const_get(:Anything)" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "abstains when a known namespace is mutated from another document" do
    project_sources = {
      "app/models/extension.rb" => <<~RUBY
        Example.define_singleton_method(:other) do
        end
      RUBY
    }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def self.save!
        end
      end
    RUBY
  end

  test "abstains when another document defines methods dynamically" do
    project_sources = { "app/models/other.rb" => "class Other; define_method(:save) {}; end" }

    assert_no_offense <<~RUBY, project_sources:
      class Example
        def save!
        end
      end
    RUBY
  end

  test "reuses the runtime-definition reading for the same project index" do
    assert_equal [ 1, 1 ], repeated_offense_counts_for(<<~RUBY)
      class Example
        def save!
        end
      end
    RUBY
  end

  test "refreshes runtime definitions after the indexed source changes" do
    source = "class Example; def save!; end; end\n"
    revisions = revisions_of(source)

    assert_equal 1, revisions.offense_count
    revisions.update("#{source}class Other; define_method(:save) {}; end\n")

    assert_equal 0, revisions.offense_count
    revisions.update(source)

    assert_equal 1, revisions.offense_count
  end

  test "abstains when a class identifier resolves to a non-namespace declaration" do
    source = <<~RUBY
      class Example
        def save!
        end
      end
    RUBY
    investigation = investigation_with(source) do |index|
      index.define_singleton_method(:resolve_constant) { |_name, _nesting| Object.new }
    end

    assert_empty investigation.offenses
  end

  test "abstains when the index omits a required singleton declaration" do
    source = <<~RUBY
      class Example
        class << self
          class << self
            def save!
            end
          end
        end
      end
    RUBY
    investigation = investigation_with(source) do |index|
      namespace = index["Example"]
      namespace.define_singleton_method(:singleton_class) { nil }
      index.define_singleton_method(:resolve_constant) { |_name, _nesting| namespace }
    end

    assert_empty investigation.offenses
  end

  test "abstains without a project index" do
    source = <<~RUBY
      class Example
        def save!
        end
      end
    RUBY
    investigation = CopTestCase::CopInvestigation.new(self.class.cop_class, source, DEFAULT_FILE)

    assert_empty investigation.offenses
  end

  test "abstains when the current buffer differs from the indexed file" do
    indexed_source = "class Example; end\n"
    current_source = "class Example; def save!; end; end\n"
    project_index = project_index_for(DEFAULT_FILE => indexed_source)
    investigation = CopTestCase::CopInvestigation.new \
      self.class.cop_class, current_source, project.path_of(DEFAULT_FILE), nil, project_index

    assert_empty investigation.offenses
  end

  private
    def repeated_offense_counts_for(source)
      revisions = revisions_of(source)

      Array.new(2) { revisions.offense_count }
    end

    def revisions_of(source)
      project_index = project_index_for(DEFAULT_FILE => source)

      CopSourceRevisions.new(self.class.cop_class, file: project.path_of(DEFAULT_FILE), project_index:)
    end

    def investigation_with(source)
      project_index = project_index_for(DEFAULT_FILE => source)
      yield project_index

      CopTestCase::CopInvestigation.new(self.class.cop_class, source, project.path_of(DEFAULT_FILE), nil, project_index)
    end
end
