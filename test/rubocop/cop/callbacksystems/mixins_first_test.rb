require "test_helper"

class RuboCop::Cop::Callbacksystems::MixinsFirstTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::MixinsFirst

  test "registers offense for an include after a constant" do
    offenses = assert_offense <<~RUBY
      class Configuration
        HOOKS = [ :before ].freeze

        include Validation
      end
    RUBY

    assert_includes offenses.first.message, "mixins come before anything else"
  end

  test "registers offense for an extend after a method" do
    assert_offense <<~RUBY
      class Configuration
        def call
        end

        extend Comparable
      end
    RUBY
  end

  test "registers offense for a prepend in a module" do
    assert_offense <<~RUBY
      module Validation
        MESSAGE = "invalid".freeze

        prepend Logging
      end
    RUBY
  end

  test "allows mixins that lead the body" do
    assert_no_offense <<~RUBY
      class Configuration
        include Validation
        extend Comparable

        HOOKS = [ :before ].freeze
      end
    RUBY
  end

  test "allows a mixin reading a constant declared above it" do
    assert_no_offense <<~RUBY
      class Configuration
        BEHAVIOR = Module.new

        include BEHAVIOR
      end
    RUBY
  end

  test "allows a class with no mixins" do
    assert_no_offense <<~RUBY
      class Configuration
        HOOKS = [ :before ].freeze

        def call
        end
      end
    RUBY
  end

  test "autocorrects by moving the mixin to the top" do
    assert_correction \
      <<~RUBY,
        class Configuration
          HOOKS = [ :before ].freeze

          include Validation
        end
      RUBY
      <<~RUBY
        class Configuration
          include Validation
          HOOKS = [ :before ].freeze
        end
      RUBY
  end

  test "autocorrects by joining the mixins already at the top" do
    assert_correction \
      <<~RUBY,
        class Configuration
          include Validation

          HOOKS = [ :before ].freeze

          extend Comparable
        end
      RUBY
      <<~RUBY
        class Configuration
          extend Comparable
          include Validation

          HOOKS = [ :before ].freeze
        end
      RUBY
  end
end
