require "test_helper"

class RuboCop::Cop::Callbacksystems::EmptyLineBetweenSectionsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::EmptyLineBetweenSections

  test "allows an attr_reader right above a delegate_missing_to, which delegates like a delegate" do
    assert_no_offense <<~RUBY
      class View
        attr_reader :order
        delegate_missing_to :order
      end
    RUBY
  end

  test "registers offense for a constant pressed against the mixins" do
    offenses = assert_offense <<~RUBY
      class Report
        include Printable
        COLUMNS = [ :name ]
      end
    RUBY

    assert_includes offenses.first.message,
      "Separate `COLUMNS = [ :name ]` from the mixins above with a blank line, since the constants are another section."
  end

  test "registers offense for a declaration pressed against the constants" do
    offenses = assert_offense <<~RUBY
      class Key < ApplicationRecord
        PRODID = "-//Callback Systems//Mentables//EN"
        has_secure_token :key
      end
    RUBY

    assert_includes offenses.first.message, "Separate `has_secure_token :key` from the constants above"
  end

  test "registers offense for a macro pressed against the declarations" do
    assert_offense <<~RUBY
      class Entry < ApplicationRecord
        belongs_to :board
        validates :name, presence: true
      end
    RUBY
  end

  test "registers offense for a method pressed against the macros" do
    assert_offense <<~RUBY
      class Entry < ApplicationRecord
        validates :name, presence: true
        def total
        end
      end
    RUBY
  end

  test "registers offense for a nested class pressed against the methods" do
    offenses = assert_offense <<~RUBY
      class Report
        def total
        end
        class Row
          def name
          end
        end
      end
    RUBY

    assert_includes offenses.first.message, "Separate `class Row` from the methods above"
  end

  test "registers offense whichever way round the sections sit" do
    assert_offense <<~RUBY
      class Report
        def total
        end
        COLUMNS = [ :name ]
      end
    RUBY
  end

  test "registers offense for a class declaration pressed against a declaration" do
    assert_offense <<~RUBY
      class Report
        Row = Data.define(:name)
        attr_reader :rows
      end
    RUBY
  end

  test "allows an attribute right above a delegate, the way the authentication generator has it" do
    assert_no_offense <<~RUBY
      class Current < ActiveSupport::CurrentAttributes
        attribute :session
        delegate :user, to: :session, allow_nil: true
      end
    RUBY
  end

  test "allows has_secure_password right above an association, the way the authentication generator has it" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        has_secure_password
        has_many :sessions, dependent: :destroy

        normalizes :email_address, with: ->(e) { e.strip.downcase }
      end
    RUBY
  end

  test "allows two constants together" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]
        Row = Data.define(:name)
      end
    RUBY
  end

  test "allows two macros together" do
    assert_no_offense <<~RUBY
      class Entry < ApplicationRecord
        validates :name, presence: true
        before_save :normalize
      end
    RUBY
  end

  test "allows private_constant right below the constant it hides" do
    assert_no_offense <<~RUBY
      class Report
        LIMIT = 10
        private_constant :LIMIT
      end
    RUBY
  end

  test "allows a mixin guarded by a modifier condition among the mixins" do
    assert_no_offense <<~RUBY
      class Report
        include Printable
        include Detection if Rails.env.local?
      end
    RUBY
  end

  test "allows a pair across a visibility modifier" do
    assert_no_offense <<~RUBY
      class Report
        def total
        end
        private
          COLUMNS = [ :name ]
      end
    RUBY
  end

  test "allows sections separated by a blank line" do
    assert_no_offense <<~RUBY
      class Entry < ApplicationRecord
        include Printable

        COLUMNS = [ :name ]

        belongs_to :board
        delegate :name, to: :board

        validates :name, presence: true

        def total
        end

        class Row
          def name
          end
        end
      end
    RUBY
  end

  test "allows a blank line written above the comment introducing the statement" do
    assert_no_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]

        # the rows the report holds
        attr_reader :rows
      end
    RUBY
  end

  test "reads the blank line past a heredoc closing the statement above" do
    assert_no_offense <<~RUBY
      class Report
        TEMPLATE = <<~SQL
          select 1

          limit 10
        SQL

        attr_reader :rows
      end
    RUBY
  end

  test "registers offense when a heredoc holds the only blank line between the two" do
    assert_offense <<~RUBY
      class Report
        TEMPLATE = <<~SQL
          select 1

          limit 10
        SQL
        attr_reader :rows
      end
    RUBY
  end

  test "registers offense when only a comment line sits between the two" do
    assert_offense <<~RUBY
      class Report
        COLUMNS = [ :name ]
        # the rows the report holds
        attr_reader :rows
      end
    RUBY
  end

  test "autocorrects by inserting a blank line above the second statement" do
    assert_correction <<~BAD, <<~GOOD
      class Key < ApplicationRecord
        PRODID = "-//Callback Systems//Mentables//EN"
        has_secure_token :key
      end
    BAD
      class Key < ApplicationRecord
        PRODID = "-//Callback Systems//Mentables//EN"

        has_secure_token :key
      end
    GOOD
  end

  test "autocorrects sections sharing a line to a fixed point" do
    corrected = <<~RUBY
      class Report
        VALUE = 1

        attr_reader :value
      end
    RUBY

    assert_correction <<~RUBY, corrected
      class Report
        VALUE = 1; attr_reader :value
      end
    RUBY
    assert_no_offense corrected
  end

  test "does not move a same-line statement into the preceding heredoc" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        TEMPLATE = <<~TEXT; attr_reader :value
          line
        TEXT
      end
    RUBY
  end

  test "autocorrects above the comment introducing the second statement" do
    assert_correction <<~BAD, <<~GOOD
      class Report
        COLUMNS = [ :name ]
        # the rows the report holds
        attr_reader :rows
      end
    BAD
      class Report
        COLUMNS = [ :name ]

        # the rows the report holds
        attr_reader :rows
      end
    GOOD
  end

  test "autocorrects leaving the comment trailing the first statement where it is" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        X = 1 # note
        has_many :rows
      end
    BAD
      class Entry < ApplicationRecord
        X = 1 # note

        has_many :rows
      end
    GOOD
  end

  test "autocorrects every boundary of the body at once" do
    assert_correction <<~BAD, <<~GOOD
      class Entry < ApplicationRecord
        include Printable
        belongs_to :board
        validates :name, presence: true
        def total
        end
      end
    BAD
      class Entry < ApplicationRecord
        include Printable

        belongs_to :board

        validates :name, presence: true

        def total
        end
      end
    GOOD
  end

  test "reads a singleton section on its own" do
    assert_offense <<~RUBY
      class Report
        class << self
          COLUMNS = [ :name ]
          def total
          end
        end
      end
    RUBY
  end

  test "allows a module whose sections are apart" do
    assert_no_offense <<~RUBY
      module Printable
        extend ActiveSupport::Concern

        def print
        end
      end
    RUBY
  end

  test "registers offense in a module" do
    assert_offense <<~RUBY
      module Printable
        extend ActiveSupport::Concern
        def print
        end
      end
    RUBY
  end

  test "allows a class whose body is a single statement" do
    assert_no_offense <<~RUBY
      class Report
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
end
