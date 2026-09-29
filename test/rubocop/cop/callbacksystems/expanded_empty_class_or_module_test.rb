require "test_helper"

class RuboCop::Cop::Callbacksystems::ExpandedEmptyClassOrModuleTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::ExpandedEmptyClassOrModule

  test "registers offense for an empty class on one line" do
    offenses = assert_offense <<~RUBY
      class PgBox::ConfigurationError < StandardError; end
    RUBY

    assert_includes offenses.first.message, "own line"
  end

  test "registers offense for an empty class without a superclass" do
    assert_offense <<~RUBY
      class PgBox::Marker; end
    RUBY
  end

  test "registers offense for an empty module on one line" do
    assert_offense <<~RUBY
      module PgBox::Diagnostics; end
    RUBY
  end

  test "registers offense for an empty module nested in a module" do
    assert_offense <<~RUBY
      module PgBox
        module Diagnostics; end
      end
    RUBY
  end

  test "allows an empty class with end on its own line" do
    assert_no_offense <<~RUBY
      class PgBox::ConfigurationError < StandardError
      end
    RUBY
  end

  test "allows a class with a body" do
    assert_no_offense <<~RUBY
      class PgBox::Configuration
        def call
        end
      end
    RUBY
  end

  test "leaves a nested empty class to the constant rule" do
    assert_no_offense <<~RUBY
      class Configuration
        class Error < StandardError; end
      end
    RUBY
  end

  test "autocorrects by moving end below the superclass" do
    assert_correction \
      <<~RUBY,
        class PgBox::ConfigurationError < StandardError; end
      RUBY
      <<~RUBY
        class PgBox::ConfigurationError < StandardError
        end
      RUBY
  end

  test "autocorrects a nested module keeping its indentation" do
    assert_correction \
      <<~RUBY,
        module PgBox
          module Diagnostics; end
        end
      RUBY
      <<~RUBY
        module PgBox
          module Diagnostics
          end
        end
      RUBY
  end

  test "autocorrects without swallowing a trailing comment" do
    assert_correction \
      <<~RUBY,
        class PgBox::Marker; end # Namespace marker.
      RUBY
      <<~RUBY
        class PgBox::Marker
        end # Namespace marker.
      RUBY
  end

  test "autocorrects an inline conditional definition without changing its nesting" do
    assert_correction \
      <<~RUBY,
        if enabled?; class PgBox::Marker; end; end
      RUBY
      <<~RUBY
        if enabled?; class PgBox::Marker
                     end; end
      RUBY
  end

  test "leaves a superclass carrying a heredoc for a human" do
    assert_uncorrectable_offense <<~RUBY
      class PgBox::Marker < resolve(<<~NAME); end
        Base
      NAME
    RUBY
  end

  test "leaves its correction at a fixed point" do
    assert_no_correction <<~RUBY
      class PgBox::Marker
      end
    RUBY
  end
end
