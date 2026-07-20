require "test_helper"

class RuboCop::Cop::Callbacksystems::RedundantConstantNamespaceTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RedundantConstantNamespace

  test "registers offense for a prefix naming the enclosing scope" do
    offenses = assert_offense <<~RUBY
      class PgBox::Configuration
        def validator
          PgBox::Configuration::Validator
        end
      end
    RUBY

    assert_includes offenses.first.message, "PgBox::Configuration"
  end

  test "registers offense inside nested definitions" do
    assert_offense <<~RUBY
      module Outer
        class Inner
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
    assert_correction \
      <<~RUBY,
        class PgBox::Configuration
          def validator
            PgBox::Configuration::Validator::Rules
          end
        end
      RUBY
      <<~RUBY
        class PgBox::Configuration
          def validator
            Validator::Rules
          end
        end
      RUBY
  end
end
