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
    assert_offense <<~RUBY, count: 2
      class Backend
        Route = Data.define(:host)
        Query = Data.define(:command)
        private_constant :Route, :Query

        def route_for(host)
          Route.new(host)
        end
      end
    RUBY
  end

  test "registers offense when nothing reads the constant" do
    assert_offense <<~RUBY
      class Backend
        FORMATS = [ :json ]
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
        MEMBERS = [ :host, :matcher ]
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
          FORMATS = [ :json ]
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

  test "registers offense when the class-level readers are test blocks" do
    assert_offense <<~RUBY
      class LoggerTest < ActiveSupport::TestCase
        LoggerProbe = Class.new(BaseLogger)
        private_constant :LoggerProbe

        setup do
          @logger = LoggerProbe.new
        end

        teardown { @logger.close }

        test "activates" do
          assert_same @logger, LoggerProbe.new.activate
        end
      end
    RUBY
  end

  test "allows a constant read from a block that runs with the class body" do
    assert_no_offense <<~RUBY
      class Report
        FORMATS = [ :json ]
        private_constant :FORMATS

        [ :csv ].each do |format|
          validates format, inclusion: { in: FORMATS }
        end
      end
    RUBY
  end

  test "allows a constant read by a macro at class level" do
    assert_no_offense <<~RUBY
      class Backend
        FORMATS = [ :json ]
        private_constant :FORMATS

        validates :format, inclusion: { in: FORMATS }
      end
    RUBY
  end

  test "allows a constant read at class level when a private section follows" do
    assert_no_offense <<~RUBY
      class Plan
        UNLIMITED = Float::INFINITY
        private_constant :UNLIMITED

        REGISTRY = { internal: { pages: UNLIMITED } }

        def pages
          REGISTRY.dig(:internal, :pages)
        end

        private
          def registry
            REGISTRY
          end
      end
    RUBY
  end

  test "allows a constant read by another constant" do
    assert_no_offense <<~RUBY
      class Backend
        FORMATS = [ :json ]
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
        FORMATS = [ :json ]
        public_constant :FORMATS

        def formats
          FORMATS
        end
      end
    RUBY
  end

  test "allows a constant written at the top level" do
    assert_no_offense <<~RUBY
      LIMIT = 10
    RUBY
  end

  test "allows private_constant inside a class_eval block whose class is not visible in the AST" do
    assert_no_offense <<~RUBY
      Object.class_eval do
        INTERNAL = Object.new
        private_constant :INTERNAL
      end
    RUBY
  end
end
