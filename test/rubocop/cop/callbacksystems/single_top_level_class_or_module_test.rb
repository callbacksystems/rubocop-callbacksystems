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
    assert_offense <<~RUBY, count: 2
      class First
      end

      class Second
      end

      module Third
      end
    RUBY
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

  test "finds definitions nested deeper than the Ruby call stack" do
    first = RuboCop::AST::Node.new(:class, [ RuboCop::AST::Node.new(:const, [ nil, :User ]), nil, nil ])
    second = RuboCop::AST::Node.new(:module, [ RuboCop::AST::Node.new(:const, [ nil, :Admin ]), nil ])
    nested_first = 2_000.times.reduce(first) do |nested, _index|
      RuboCop::AST::Node.new(:kwbegin, [ nested ])
    end
    tree = RuboCop::AST::Node.new(:begin, [ nested_first, second ])
    analysis = RuboCop::Cop::Callbacksystems::SingleTopLevelClassOrModule::TopLevelDefinitions.new(tree)
    offenses = []

    analysis.each_offense { offenses << it }

    assert_equal [ second ], offenses.map(&:range)
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
  test "allows a class extending one written above it in the same file" do
    assert_no_offense <<~RUBY
      class BaseTest < ActiveSupport::TestCase
      end

      class VariantTest < BaseTest
      end
    RUBY
  end

  test "allows every class of a hierarchy the file declares together" do
    assert_no_offense <<~RUBY
      class BaseTest < ActiveSupport::TestCase
      end

      class FirstTest < BaseTest
      end

      class SecondTest < BaseTest
      end
    RUBY
  end

  test "registers offense for a class extending something from outside the file" do
    assert_offense <<~RUBY
      class UserTest < ActiveSupport::TestCase
      end

      class AdminTest < ActiveSupport::TestCase
      end
    RUBY
  end

  test "registers offense for a module beside a class it does not extend" do
    assert_offense <<~RUBY
      class BaseTest < ActiveSupport::TestCase
      end

      module Helpers
      end
    RUBY
  end

  test "registers offense for a second top-level class inside a conditional" do
    assert_offense <<~RUBY
      class User
      end

      if feature_enabled?
        class Admin
        end
      end
    RUBY
  end

  test "registers offense for a second top-level class builder assignment" do
    assert_offense <<~RUBY
      class User
      end

      Admin = Class.new
    RUBY
  end

  test "registers offenses for class and module builder blocks" do
    assert_offense <<~RUBY, count: 4
      class User
      end

      Admin = Class.new do
      end

      Namespace = Module.new do
      end

      Row = Struct.new(:identifier) do
      end

      Entry = Data.define(:identifier) do
      end
    RUBY
  end

  test "registers an explicitly top-level builder without mistaking a namespaced lookalike for one" do
    assert_offense <<~RUBY, count: 1
      class User
      end

      Admin = ::Class.new
      Value = Factory::Data.define(:identifier)
    RUBY
  end

  test "allows a non-class constant assignment beside a class" do
    assert_no_offense <<~RUBY
      class User
      end

      DEFAULT_ROLE = :member
    RUBY
  end

  test "allows a receiverless new assignment beside a class" do
    assert_no_offense <<~RUBY
      class User
      end

      DEFAULT_USER = new
    RUBY
  end

  test "allows a class builder and the class extending it" do
    assert_no_offense <<~RUBY
      BaseTest = Class.new

      class UserTest < BaseTest
      end
    RUBY
  end

  test "allows a namespaced class builder and the class extending it" do
    assert_no_offense <<~RUBY
      Domain::BaseTest = Class.new

      class UserTest < Domain::BaseTest
      end
    RUBY
  end

  test "allows class builders extending one another" do
    assert_no_offense <<~RUBY
      BaseTest = Class.new(ActiveSupport::TestCase)
      UserTest = Class.new(BaseTest)
    RUBY
  end

  test "allows qualified class builders extending one another" do
    assert_no_offense <<~RUBY
      Domain::BaseTest = ::Class.new(ActiveSupport::TestCase)
      Domain::UserTest = ::Class.new(Domain::BaseTest)
    RUBY
  end

  test "does not read the first argument of another builder as its superclass" do
    assert_offense <<~RUBY
      BaseTest = Class.new
      UserTest = Data.define(BaseTest)
    RUBY
  end
end
