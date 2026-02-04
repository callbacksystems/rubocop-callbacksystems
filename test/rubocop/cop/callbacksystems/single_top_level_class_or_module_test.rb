require "test_helper"

class SingleTopLevelClassOrModuleTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleTopLevelClassOrModule

  test "registers offense for multiple top-level classes" do
    offenses = assert_offense <<~RUBY
      class User
      end

      class Admin
      end
    RUBY
    assert_includes offenses.first.message, "Only one top-level class or module"
  end

  test "registers offense for multiple top-level modules" do
    offenses = assert_offense <<~RUBY
      module Authentication
      end

      module Authorization
      end
    RUBY
    assert_includes offenses.first.message, "Only one top-level class or module"
  end

  test "registers offense for mixed top-level class and module" do
    offenses = assert_offense <<~RUBY
      class User
      end

      module UserHelpers
      end
    RUBY
    assert_includes offenses.first.message, "Only one top-level class or module"
  end

  test "registers offense for three top-level definitions" do
    offenses = assert_offense <<~RUBY
      class First
      end

      class Second
      end

      module Third
      end
    RUBY
    assert_equal 2, offenses.size
  end

  test "allows single top-level class" do
    assert_no_offense <<~RUBY
      class User
        def name
        end
      end
    RUBY
  end

  test "allows single top-level module" do
    assert_no_offense <<~RUBY
      module Authentication
        def authenticate
        end
      end
    RUBY
  end

  test "allows nested classes inside top-level class" do
    assert_no_offense <<~RUBY
      class User
        class Profile
        end

        class Settings
        end
      end
    RUBY
  end

  test "allows nested modules inside top-level class" do
    assert_no_offense <<~RUBY
      class User
        module Validations
        end

        module Callbacks
        end
      end
    RUBY
  end

  test "allows nested classes inside top-level module" do
    assert_no_offense <<~RUBY
      module Authentication
        class Token
        end

        class Session
        end
      end
    RUBY
  end

  test "allows deeply nested definitions" do
    assert_no_offense <<~RUBY
      class Outer
        class Middle
          class Inner
          end

          module Helper
          end
        end
      end
    RUBY
  end

  test "allows empty file" do
    assert_no_offense ""
  end

  test "allows file with only method calls" do
    assert_no_offense <<~RUBY
      require "something"
      include SomeModule
    RUBY
  end
end
