require "test_helper"

class RuboCop::Cop::Callbacksystems::RedundantConstantNamespaceTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RedundantConstantNamespace
  self.project_indexed = true

  test "allows a constant that stands alone in the file" do
    assert_no_offense <<~RUBY
      Foo
    RUBY
  end

  test "registers offense for a prefix naming the enclosing scope" do
    project_sources = {
      "app/models/pg_box.rb" => <<~RUBY
        module PgBox
          class Configuration
            class Validator
            end
          end
        end
      RUBY
    }

    source = <<~RUBY
      class PgBox::Configuration
        def validator
          PgBox::Configuration::Validator
        end
      end
    RUBY
    offenses = assert_offense source, project_sources: project_sources

    assert_includes offenses.first.message, "PgBox::Configuration"
  end

  test "registers offense inside nested definitions" do
    assert_offense <<~RUBY
      module Outer
        class Inner
          class Target
          end

          def target
            Outer::Inner::Target
          end
        end
      end
    RUBY
  end

  test "allows a reference beneath a namespace Rubydex only inferred" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        class Validator
        end

        def validator
          PgBox::Configuration::Validator
        end
      end
    RUBY
  end

  test "allows an inferred target even when both spellings reach its placeholder" do
    project_sources = { "app/models/child.rb" => "class Outer::Inner::Missing::Child; end\n" }

    assert_no_offense <<~RUBY, project_sources:
      module Outer
        class Inner
          def target
            Outer::Inner::Missing
          end
        end
      end
    RUBY
  end

  test "does not infer equivalent resolution without the project index" do
    assert_no_offense <<~RUBY, project_sources: false
      module Outer
        class Inner
          class Target
          end

          def target
            Outer::Inner::Target
          end
        end
      end
    RUBY
  end

  test "allows a prefix that is not a lexical scope" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        def secrets
          PgBox::Secrets
        end
      end
    RUBY
  end

  test "allows a prefix naming an outer scope that could be shadowed" do
    assert_no_offense <<~RUBY
      module Outer
        class Inner
          def target
            Outer::Target
          end
        end
      end
    RUBY
  end

  test "registers offense in a subclass when both spellings resolve to the inherited constant" do
    assert_offense <<~RUBY
      module Outer
        class Base
          class Target
          end
        end

        class Inner < Base
          def target
            Outer::Inner::Target
          end
        end
      end
    RUBY
  end

  test "allows a qualified lookup in a subclass when an outer lexical constant wins unqualified" do
    assert_no_offense <<~RUBY
      module Outer
        class Target
        end

        class Base
          class Target
          end
        end

        class Inner < Base
          def target
            Outer::Inner::Target
          end
        end
      end
    RUBY
  end

  test "allows a top-level constant reference" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        def validator
          ::PgBox::Configuration::Validator
        end
      end
    RUBY
  end

  test "allows the constant a nested definition names" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        class PgBox::Configuration::Validator
        end
      end
    RUBY
  end

  test "allows a reference to the enclosing scope itself" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        def itself
          PgBox::Configuration
        end
      end
    RUBY
  end

  test "autocorrects by dropping the prefix" do
    project_sources = {
      "app/models/pg_box.rb" => <<~RUBY
        module PgBox
          class Configuration
            class Validator
              class Rules
              end
            end
          end
        end
      RUBY
    }

    original = <<~RUBY
      class PgBox::Configuration
        def validator
          PgBox::Configuration::Validator::Rules
        end
      end
    RUBY
    corrected = <<~RUBY
      class PgBox::Configuration
        def validator
          Validator::Rules
        end
      end
    RUBY

    assert_correction original, corrected, project_sources: project_sources
  end
end
