require "test_helper"

class RuboCop::Cop::Callbacksystems::BodyOrderTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::BodyOrder

  test "moves a constant together with the body of its heredoc" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
        end

        TEMPLATE = <<~SQL
          SELECT 1
        SQL
      end
    BAD
      class Report
        TEMPLATE = <<~SQL
          SELECT 1
        SQL

        def total
        end
      end
    GOOD
  end

  test "keeps two constants adjacent when the blank line between them sits inside a heredoc" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
          rows.size
        end

        TEMPLATE = <<~SQL
          select 1

          limit 10
        SQL
        LIMIT = 10
      end
    BAD
      class Report
        TEMPLATE = <<~SQL
          select 1

          limit 10
        SQL
        LIMIT = 10

        def total
          rows.size
        end
      end
    GOOD
  end

  test "moves a declaration together with the comment trailing it" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        validates :name, presence: true
        belongs_to :board # the one it hangs from
      end
    BAD
      class Entry < ApplicationRecord
        belongs_to :board # the one it hangs from
        validates :name, presence: true
      end
    GOOD
  end

  test "keeps the blank line the author left between declarations of one kind" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        validates :name, presence: true

        after_create :notify
        belongs_to :board
      end
    BAD
      class Entry < ApplicationRecord
        belongs_to :board

        validates :name, presence: true

        after_create :notify
      end
    GOOD
  end

  test "registers offense for an association below a macro" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        validates :name, presence: true
        belongs_to :board
      end
    BAD
      class Entry < ApplicationRecord
        belongs_to :board
        validates :name, presence: true
      end
    GOOD
  end

  test "registers offense for a macro below a method" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        def total
          1
        end

        scope :recent, -> { order(id: :desc) }
      end
    BAD
      class Entry < ApplicationRecord
        scope :recent, -> { order(id: :desc) }

        def total
          1
        end
      end
    GOOD
  end

  test "reports without correcting a macro that would trade places with its method" do
    assert_uncorrectable_offense <<~RUBY
      class Entry < ApplicationRecord
        def recent
          :manual
        end

        attribute :recent, :string
      end
    RUBY
  end

  test "registers offense for a macro written with a block below a method" do
    assert_offense <<~RUBY
      class Entry < ApplicationRecord
        def total
          1
        end

        scope :recent do
          order(id: :desc)
        end
      end
    RUBY
  end

  test "reads a delegated type and an attachment as associations" do
    assert_no_offense <<~RUBY
      class Block < ApplicationRecord
        delegated_type :blockable, types: %w[ Heading Image ], dependent: :destroy
        belongs_to :page
        has_one_attached :cover
        has_rich_text :body

        delegate :account, to: :page

        positioned on: :page
      end
    RUBY
  end

  test "reads an association extended with a block as an association" do
    assert_correction <<~BAD, <<~GOOD
      class Page < ApplicationRecord
        has_many :blocks do
          def published
            where(published: true)
          end
        end

        normalizes :title, with: -> { it.strip }

        has_one_attached :logo
      end
    BAD
      class Page < ApplicationRecord
        has_many :blocks do
          def published
            where(published: true)
          end
        end

        has_one_attached :logo

        normalizes :title, with: -> { it.strip }
      end
    GOOD
  end

  test "allows private_constant right below the constants it hides, above the state declarations" do
    assert_no_offense <<~RUBY
      class Plan
        UNLIMITED = Float::INFINITY
        VERSION_PATTERN = /_v\\d+\\z/
        private_constant :UNLIMITED, :VERSION_PATTERN

        REGISTRY = { internal: { pages: UNLIMITED } }

        attr_reader :key

        delegate :pages, to: :limits
      end
    RUBY
  end

  test "autocorrects by lifting a private_constant together with the constant it marks" do
    assert_correction <<~BAD, <<~GOOD
      class Backend
        def route_for(host)
        end

        Route = Data.define(:host)
        private_constant :Route
      end
    BAD
      class Backend
        Route = Data.define(:host)
        private_constant :Route

        def route_for(host)
        end
      end
    GOOD
  end

  test "registers offense for a private_constant left below the state declarations" do
    assert_correction <<~BAD, <<~GOOD
      class Backend
        LIMIT = 10
        attr_reader :key
        private_constant :LIMIT
      end
    BAD
      class Backend
        LIMIT = 10
        private_constant :LIMIT
        attr_reader :key
      end
    GOOD
  end

  test "allows the state declarations above the associations and the delegates below them" do
    assert_no_offense <<~RUBY
      class Entry < ApplicationRecord
        attr_reader :rows
        attribute :draft, :boolean
        class_attribute :limit
        has_secure_token :key

        belongs_to :board
        delegate :name, to: :board
        validates :name, presence: true

        def total
          1
        end
      end
    RUBY
  end

  test "reports without moving an attr_accessor across a framework declaration with unknown methods" do
    assert_uncorrectable_offense <<~RUBY
      class Selection < ApplicationRecord
        belongs_to :listing
        delegate :offering, to: :listing

        before_validation :build_selectable, on: :create

        attr_accessor :selection_params
      end
    RUBY
  end

  test "leaves alone has_secure_password above the associations, the way the authentication generator has it" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        has_secure_password
        has_many :sessions, dependent: :destroy

        normalizes :email_address, with: ->(e) { e.strip.downcase }
      end
    RUBY
  end

  test "leaves alone an attribute written right above a delegate, the way the authentication generator has it" do
    assert_no_offense <<~RUBY
      class Current < ActiveSupport::CurrentAttributes
        attribute :session
        delegate :user, to: :session, allow_nil: true
      end
    RUBY
  end

  test "registers offense for a delegate above the association it reaches through" do
    assert_offense <<~RUBY
      class Entry < ApplicationRecord
        delegate :name, to: :board
        belongs_to :board
      end
    RUBY
  end

  test "reports without correcting declarations whose order decides which method remains" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order
        attr_reader :total
      end
    RUBY
  end

  test "reports without reversing a prefixed delegate and the method it defines" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :name, to: :user, prefix: true
        attr_reader :user_name
      end
    RUBY
  end

  test "reports without reversing a scope and the singleton method it defines" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def self.active
          all
        end

        scope :active, -> { where(active: true) }
      end
    RUBY
  end

  test "reports without moving a delegate whose defined methods are dynamic" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def name
          "report"
        end

        delegate *METHODS, to: :user
      end
    RUBY
  end

  test "reports without moving a dynamic scope across a method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def self.active
          all
        end

        scope scope_name, -> { where(active: true) }
      end
    RUBY
  end

  test "reports without moving a dynamically named accessor across a method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def value
          :method
        end

        attr_reader method_name
      end
    RUBY
  end

  test "reports without moving has_secure_password across a method its defaults may define" do
    assert_uncorrectable_offense <<~RUBY
      class User
        def password=(value)
          @password = value
        end

        has_secure_password
      end
    RUBY
  end

  test "reports without reversing delegate_missing_to and method_missing" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def method_missing(name, ...)
          super
        end

        delegate_missing_to :fallback
      end
    RUBY
  end

  test "reads the writer made by attr_writer when preserving declaration precedence" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total=, to: :order
        attr_writer :total
      end
    RUBY
  end

  test "registers offense for a constant below a method" do
    assert_offense <<~RUBY
      class Report
        def total
          COLUMNS.size
        end

        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "registers offense for a constant below a nested class" do
    assert_offense <<~RUBY
      class Report
        class Row
        end

        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "registers offense for a constant below an attr_reader" do
    assert_offense <<~RUBY
      class Report
        attr_reader :rows

        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "allows a constant above everything else" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]

        def total
          COLUMNS.size
        end
      end
    RUBY
  end

  test "allows a constant below the mixins" do
    assert_no_offense <<~RUBY
      class Report
        include Printable
        extend Countable

        COLUMNS = [ :name ]

        def total
        end
      end
    RUBY
  end

  test "allows a constant below a class attribute set on self" do
    assert_no_offense <<~RUBY
      class Report
        self.table_name = "reports"

        COLUMNS = [ :name ]

        def total
        end
      end
    RUBY
  end

  test "reads each visibility section on its own" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]

        def total
        end

        private
          SEPARATOR = ", "

          def joined
          end
      end
    RUBY
  end

  test "registers offense for a constant below a method of the private section" do
    assert_offense <<~RUBY
      class Report
        private
          def joined
          end

          SEPARATOR = ", "
      end
    RUBY
  end

  test "lifts a constant together with the one it reads, keeping their order" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
        end

        WIDTH = 10
        PADDED = WIDTH + 2
      end
    BAD
      class Report
        WIDTH = 10
        PADDED = WIDTH + 2

        def total
        end
      end
    GOOD
  end

  test "allows a constant built from a local assigned above it" do
    assert_no_offense <<~RUBY
      class Report
        def total
        end

        separator = ", "
        FORMATS = { csv: separator }
      end
    RUBY
  end

  test "registers offense for a type declaration above a plain constant" do
    assert_offense <<~RUBY
      class Report
        Row = Data.define(:name)
        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "allows a type declaration below the plain constants" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]
        Row = Data.define(:name)

        def total
        end
      end
    RUBY
  end

  test "allows a type declaration when the section holds no plain constant" do
    assert_no_offense <<~RUBY
      class Report
        Row = Data.define(:name)
        Cell = Struct.new(:value)

        def total
        end
      end
    RUBY
  end

  test "registers offense for a type declaration below a method" do
    assert_offense <<~RUBY
      class Report
        def total
        end

        Row = Data.define(:name)
      end
    RUBY
  end

  test "allows a module whose body holds a single constant" do
    assert_no_offense <<~RUBY
      module Report
        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "allows an empty class" do
    assert_no_offense <<~RUBY
      class Report
      end
    RUBY
  end

  test "autocorrects by moving the constant above the method" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
          COLUMNS.size
        end

        COLUMNS = [ :name ]
      end
    BAD
      class Report
        COLUMNS = [ :name ]

        def total
          COLUMNS.size
        end
      end
    GOOD
  end

  test "autocorrects carrying the comments written above the constant" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
        end

        # what the columns are for
        COLUMNS = [ :name ]
      end
    BAD
      class Report
        # what the columns are for
        COLUMNS = [ :name ]

        def total
        end
      end
    GOOD
  end

  test "reports without lifting a declaration whose tooling directive would change scope" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def total
        end

        # :nocov:
        COLUMNS = []
        # :nocov:
      end
    RUBY
  end

  test "reports without lifting a declaration across an independent comment" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        def total
        end

        # Values used by another section.

        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "autocorrects every constant of the section at once, values before types" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
        end

        Row = Data.define(:name)
        COLUMNS = [ :name ]
      end
    BAD
      class Report
        COLUMNS = [ :name ]
        Row = Data.define(:name)

        def total
        end
      end
    GOOD
  end

  test "registers offense for an attribute macro above a constant" do
    assert_offense <<~RUBY
      class Report
        attr_reader :rows
        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "allows an attribute macro after the constants and before the methods" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]
        Row = Data.define(:name)

        attr_reader :rows
        delegate :size, to: :rows

        def total
        end
      end
    RUBY
  end

  test "registers offense for a delegate below a method" do
    assert_offense <<~RUBY
      class Report
        def total
        end

        delegate :size, to: :rows
      end
    RUBY
  end

  test "autocorrects the whole section into constants, classes, macros, methods" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        attr_reader :rows
        Row = Data.define(:name)
        COLUMNS = [ :name ]

        def total
        end
      end
    BAD
      class Report
        COLUMNS = [ :name ]
        Row = Data.define(:name)
        attr_reader :rows

        def total
        end
      end
    GOOD
  end

  test "reads the case of the name, not what built the class" do
    assert_offense <<~RUBY
      class Report
        Row = build_row_class
        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "treats a screaming snake case name as a value whatever built it" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = fetch_columns
        Row = Data.define(:name)
      end
    RUBY
  end

  test "registers offense for a mixin after a constant" do
    assert_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]

        include Printable
      end
    RUBY
  end

  test "registers offense for a prepend after a method in a module" do
    assert_offense <<~RUBY
      module Printable
        def print
        end

        prepend Formatting
      end
    RUBY
  end

  test "allows mixins that lead the body" do
    assert_no_offense <<~RUBY
      class Report
        include Printable
        extend Countable

        COLUMNS = [ :name ]

        def total
        end
      end
    RUBY
  end

  test "allows a mixin guarded by a modifier condition among the mixins" do
    assert_no_offense <<~RUBY
      class Report
        include Printable
        include Detection if Rails.env.local?

        allow_browser versions: :modern

        def total
        end
      end
    RUBY
  end

  test "autocorrects by moving a mixin guarded by a modifier condition above the macros" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        include Printable

        allow_browser versions: :modern

        include Detection unless Rails.env.production?
      end
    BAD
      class Report
        include Printable

        include Detection unless Rails.env.production?

        allow_browser versions: :modern
      end
    GOOD
  end

  test "leaves alone a mixin reading a constant declared above it" do
    offenses = assert_offense <<~RUBY
      class Report
        def total
        end

        MODULES = [ Printable ]
        include MODULES.first
      end
    RUBY

    assert_equal 1, offenses.size, "Only MODULES can move; the include cannot cross it"
  end

  test "autocorrects by moving the mixin above the method" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        def total
        end

        include Printable
      end
    BAD
      class Report
        include Printable

        def total
        end
      end
    GOOD
  end

  test "registers offense for a method after a nested class" do
    assert_offense <<~RUBY
      class Report
        private
          class Row
            def name
            end
          end

          def total
          end
      end
    RUBY
  end

  test "reports the nested class once rather than every method it sits over" do
    offenses = assert_offense <<~RUBY, count: 1
      class Report
        private
          class Row
            def name
            end
          end

          def total
          end

          def average
          end
      end
    RUBY

    assert_includes offenses.first.message, "Move `class Row` below `def total`"
  end

  test "allows nested classes that close the section" do
    assert_no_offense <<~RUBY
      class Report
        private
          def total
          end

          class Row
            def name
            end
          end
      end
    RUBY
  end

  test "allows a class builder with no block among the declarations" do
    assert_no_offense <<~RUBY
      class Report
        private
          Row = Struct.new(:name)

          def total
          end
      end
    RUBY
  end

  test "allows a class builder given a block to close the section, like any nested class" do
    assert_no_offense <<~RUBY
      class Verification
        private
          def execute_once
            Result.new(host: host)
          end

          Result = Data.define(:host) do
            def to_s
              host
            end
          end
      end
    RUBY
  end

  test "keeps a namespaced builder lookalike with the class-named constants" do
    assert_no_offense <<~RUBY
      class Route
        Result = Domain::Data.define(:host) do
          def render = host
        end

        def call = Result.new(host)
      end
    RUBY
  end

  test "registers offense for a method after a class builder given a block" do
    assert_offense <<~RUBY
      class Verification
        private
          Result = Data.define(:host) do
            def to_s
              host
            end
          end

          def execute_once
          end
      end
    RUBY
  end

  test "reads a singleton section on its own" do
    assert_offense <<~RUBY
      class Report
        class << self
          def total
          end

          COLUMNS = [ :name ]
        end
      end
    RUBY
  end
  test "leaves a constant that reads a nested class declared above it" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def initialize(name)
            @name = name
          end
        end

        HEADER = Row.new("total")
      end
    RUBY
  end

  test "leaves a mixin that reads a module declared above it" do
    assert_no_offense <<~RUBY
      class Report
        module Formatting
        end

        include Formatting
      end
    RUBY
  end

  test "still lifts a constant that reads nothing declared above it" do
    assert_offense <<~RUBY
      class Report
        class Row
        end

        COLUMNS = [ :name ]
      end
    RUBY
  end
  test "sinks a nested class below the methods it sat over" do
    original = <<~RUBY
      class Report
        class Row
          def name
          end
        end

        def total
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        def total
        end

        class Row
          def name
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "sinks a nested class carrying the comments written above it" do
    original = <<~RUBY
      class Report
        # One row of the report.
        class Row
          def name
          end
        end

        def total
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        def total
        end

        # One row of the report.
        class Row
          def name
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "reports without sinking a nested class whose tooling directive would change scope" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        # :nocov:
        class Row
          def name
          end
        end

        def total
        end
        # :nocov:
      end
    RUBY
  end

  test "reports without sinking a nested class across an independent comment" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        class Row
          def name
          end
        end

        # Public behavior.

        def total
        end
      end
    RUBY
  end

  test "sinks several nested classes keeping the order they were written in" do
    original = <<~RUBY
      class Report
        class Row
          def name
          end
        end

        class Column < Row
          def label
          end
        end

        def total
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        def total
        end

        class Row
          def name
          end
        end

        class Column < Row
          def label
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "sinks a nested class past a class that already closes the section" do
    original = <<~RUBY
      class Report
        class Row
          def name
          end
        end

        def total
        end

        class Footer
          def label
          end
        end
      end
    RUBY

    corrected = <<~RUBY
      class Report
        def total
        end

        class Footer
          def label
          end
        end

        class Row
          def name
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "leaves a nested class a declaration of the same body reads" do
    assert_no_offense <<~RUBY
      class Report
        class Row
          def name
          end
        end

        HEADER = Row.new

        def total
        end
      end
    RUBY
  end

  test "leaves a nested class a mixin of the same body names" do
    assert_no_offense <<~RUBY
      class Report
        module Formatting
          def label
          end
        end

        include Formatting

        def total
        end
      end
    RUBY
  end
  test "leaves the section alone when a declaration between others cannot move" do
    original = <<~RUBY
      class Parser
        private
          delegate :parse, to: :engine

          class Engine
            def parse
            end
          end
          ENGINE = Engine.new
          SUFFIX = /c/

          def run
          end
      end
    RUBY

    assert_correction original, original
  end

  test "reports without a fix when a declaration between others cannot move" do
    assert_uncorrectable_offense <<~RUBY
      class Parser
        private
          delegate :parse, to: :engine

          class Engine
            def parse
            end
          end
          ENGINE = Engine.new
          SUFFIX = /c/

          def run
          end
      end
    RUBY
  end

  test "reports a nested module sitting above what the body does" do
    offenses = assert_offense <<~RUBY
      module Wrapper
        module Filters
          def filter
          end
        end

        def self.content_for(mail)
        end
      end
    RUBY

    assert_includes offenses.first.message, "Move `module Filters` below `def self.content_for(mail)`"
  end

  test "sinks a nested module below the methods it sat over" do
    original = <<~RUBY
      module Wrapper
        module Filters
          def filter
          end
        end

        def self.content_for(mail)
        end
      end
    RUBY

    corrected = <<~RUBY
      module Wrapper
        def self.content_for(mail)
        end

        module Filters
          def filter
          end
        end
      end
    RUBY

    assert_correction original, corrected
  end

  test "allows an empty file" do
    assert_no_offense ""
  end
end
