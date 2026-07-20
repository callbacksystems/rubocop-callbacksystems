require "test_helper"

class RuboCop::Cop::Callbacksystems::PrivateConstantsInPrivateSectionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateConstantsInPrivateSection

  test "registers offense when only method bodies read the constant" do
    offenses = assert_offense <<~RUBY
      class Backend
        Route = Data.define(:host, :matcher)
        private_constant :Route

        def route_for(host)
          Route.new(host, nil)
        end
      end
    RUBY

    assert_includes offenses.first.message, "Route"
  end

  test "registers an offense for every marked constant" do
    offenses = assert_offense <<~RUBY
      class Backend
        Route = Data.define(:host)
        Query = Data.define(:command)
        private_constant :Route, :Query

        def route_for(host)
          Route.new(host)
        end
      end
    RUBY

    assert_equal 2, offenses.size
  end

  test "registers offense when nothing reads the constant" do
    assert_offense <<~RUBY
      class Backend
        FORMATS = [ :json ].freeze
        private_constant :FORMATS
      end
    RUBY
  end

  test "registers offense for a nested class read from a method" do
    assert_offense <<~RUBY
      class Backend
        class Route
        end
        private_constant :Route

        def route_for(host)
          Route.new(host)
        end
      end
    RUBY
  end

  test "registers offense when the class-level readers are private too" do
    assert_offense <<~RUBY
      class Analysis
        MEMBERS = [ :host, :matcher ].freeze
        private_constant :MEMBERS

        private
          Route = Data.define(*MEMBERS)
          Result = Data.define(*MEMBERS, :findings)
      end
    RUBY
  end

  test "reports the marker as redundant when the constant already sits in the private section" do
    offenses = assert_offense <<~RUBY
      class Backend
        def formats
          FORMATS
        end

        private
          FORMATS = [ :json ].freeze
          private_constant :FORMATS
      end
    RUBY

    assert_includes offenses.first.message, "already declared in the private section"
  end

  test "registers offense when the class-level read names another constant ending the same" do
    assert_offense <<~RUBY
      class Inventory
        MARKER = /\\A\#{Regexp.escape(FileEntry::MARKER)}\\z/
        private_constant :MARKER

        private
          def marked?(line)
            line.match?(MARKER)
          end
      end
    RUBY
  end

  test "allows a constant read by a macro at class level" do
    assert_no_offense <<~RUBY
      class Backend
        FORMATS = [ :json ].freeze
        private_constant :FORMATS

        validates :format, inclusion: { in: FORMATS }
      end
    RUBY
  end

  test "allows a constant read by another constant" do
    assert_no_offense <<~RUBY
      class Backend
        FORMATS = [ :json ].freeze
        private_constant :FORMATS

        DEFAULT_FORMAT = FORMATS.first
      end
    RUBY
  end

  test "allows a constant naming a superclass at class level" do
    assert_no_offense <<~RUBY
      class Backend
        ROOT = Object
        private_constant :ROOT

        class Route < ROOT
        end
      end
    RUBY
  end

  test "ignores calls that are not private_constant" do
    assert_no_offense <<~RUBY
      class Backend
        FORMATS = [ :json ].freeze
        public_constant :FORMATS

        def formats
          FORMATS
        end
      end
    RUBY
  end
end
