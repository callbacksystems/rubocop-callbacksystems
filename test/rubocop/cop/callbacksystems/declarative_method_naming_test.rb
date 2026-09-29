require "test_helper"

class DeclarativeMethodNamingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::DeclarativeMethodNaming

  test "allows a declarative noun name" do
    assert_no_offense <<~RUBY
      def total
        a + b
      end
    RUBY
  end

  test "allows noun-verbs that read as nouns" do
    assert_no_offense <<~RUBY
      def count
        items.length
      end
    RUBY
  end

  test "allows a name that does not lead with a producer verb" do
    assert_no_offense <<~RUBY
      def name
        label
      end
    RUBY
  end

  test "allows predicate methods" do
    assert_no_offense <<~RUBY
      def valid?
        errors.empty?
      end
    RUBY
  end

  test "allows bang methods" do
    assert_no_offense <<~RUBY
      def save!
        persist || raise
      end
    RUBY
  end

  test "allows setter methods" do
    assert_no_offense <<~RUBY
      def get_value=(value)
        @value = value
      end
    RUBY
  end

  test "allows initialize" do
    assert_no_offense <<~RUBY
      def initialize
        @ready = true
      end
    RUBY
  end

  test "registers offense for producer verb with a noun and no arguments, suggesting the noun" do
    offenses = assert_offense <<~RUBY, count: 1
      def compute_total
        a + b
      end
    RUBY

    assert_includes offenses.first.message, "Rename `compute_total` to `total`"
    assert_includes offenses.first.message, "not the action `compute`"
  end

  test "registers offense for producer verb with arguments, asking to relate to the argument" do
    offenses = assert_offense <<~RUBY, count: 1
      def get_user(id)
        users[id]
      end
    RUBY

    assert_includes offenses.first.message, "Rename `get_user` for the value, related to its argument"
    assert_includes offenses.first.message, "not the action `get`"
  end

  test "registers offense for a method named with a producer verb" do
    offenses = assert_offense <<~RUBY, count: 1
      def build_label(values)
        Label.new(values.join)
      end
    RUBY

    assert_includes offenses.first.message, "Rename `build_label` for the value, related to its argument"
  end

  test "allows a bare producer verb: there is no noun to rename it to" do
    assert_no_offense <<~RUBY
      def compute
        heavy_work
      end
    RUBY
  end

  test "allows the bare verb itself, like fetch or get in a client" do
    assert_no_offense <<~RUBY
      def fetch
        store.read
      end
    RUBY
  end

  test "allows a producer verb that appends to state with <<" do
    assert_no_offense <<~RUBY
      def build_log
        @entries << current
        @entries
      end
    RUBY
  end

  test "allows a producer verb that mutates a set with add" do
    assert_no_offense <<~RUBY
      def build_tags
        @tags.add(tag)
        @tags
      end
    RUBY
  end

  test "allows a producer verb followed straight by a connector: no noun to rename to" do
    assert_no_offense <<~RUBY
      def find_in_scope
        scope.detect(&:match?)
      end
    RUBY
  end

  test "allows a producer verb glued to a connector even with arguments" do
    assert_no_offense <<~RUBY
      def load_for(person)
        events_for(person) + blocks_for(person)
      end
    RUBY
  end

  test "allows a method that delegates within its own verb family" do
    assert_no_offense <<~RUBY
      def format_money(money)
        Worldwide.currency(money).format_short(money)
      end
    RUBY
  end

  test "allows a producer verb wrapping the same verb, like a find wrapper" do
    assert_no_offense <<~RUBY
      def find_account_by_cookie
        accounts.find_by(id: cookie)
      end
    RUBY
  end

  test "allows a producer verb safely navigating to the same verb family" do
    assert_no_offense <<~RUBY
      def find_account_by_cookie
        accounts&.find_by(id: cookie)
      end
    RUBY
  end

  test "still registers a pure producer that only happens to use safe navigation" do
    assert_offense <<~RUBY
      def compute_total
        amounts&.sum
      end
    RUBY
  end

  test "allows a builder whose suggested noun already names a reader sibling" do
    assert_no_offense <<~RUBY
      class Plan
        attr_reader :prices

        def build_prices
          properties.to_h { |currency, cents| [ currency, Money.new(cents) ] }
        end
      end
    RUBY
  end

  test "allows a builder whose suggested noun already names a method sibling" do
    assert_no_offense <<~RUBY
      class Plan
        def key
          @key
        end

        def lookup_key
          "prefix_\#{key}"
        end
      end
    RUBY
  end

  test "does not take a method from a nested class as the suggested noun" do
    assert_offense <<~RUBY
      class Plan
        class Inner
          def prices
            []
          end
        end

        def build_prices
          properties.to_h
        end
      end
    RUBY
  end

  test "does not take a singleton method as the suggested instance noun" do
    assert_offense <<~RUBY
      class Plan
        def self.prices
          []
        end

        def build_prices
          properties.to_h
        end
      end
    RUBY
  end

  test "does not take a singleton reader as the suggested instance noun" do
    assert_offense <<~RUBY
      class Plan
        class << self
          attr_reader :prices
        end

        def build_prices
          properties.to_h
        end
      end
    RUBY
  end

  test "allows a singleton builder whose suggested noun names a singleton reader" do
    assert_no_offense <<~RUBY
      class Plan
        class << self
          attr_reader :prices

          def build_prices
            properties.to_h
          end
        end
      end
    RUBY
  end

  test "reader declarations are found through call arguments deeper than Ruby's call stack" do
    reader = RuboCop::AST::SendNode.new(:send, [ nil, :attr_reader, RuboCop::AST::Node.new(:sym, [ :prices ]) ])
    body = 5_000.times.reduce(reader) do |argument, _|
      RuboCop::AST::SendNode.new(:send, [ nil, :wrapper, argument ])
    end

    macros = RuboCop::Cop::Callbacksystems::DeclarativeMethodNaming::DeclaredValues::ReaderMacros.new(body)

    assert_equal [ reader ], macros.each.to_a
  end

  test "registers offense suggesting the noun when the noun already carries a connector" do
    offenses = assert_offense <<~RUBY, count: 1
      def get_user_by_id(id)
        users[id]
      end
    RUBY

    assert_includes offenses.first.message, "Rename `get_user_by_id` to `user_by_id`"
    assert_includes offenses.first.message, "not the action `get`"
  end

  test "subsumes the old extract naming smell" do
    offenses = assert_offense <<~RUBY, count: 1
      def extract_title
        node.title
      end
    RUBY

    assert_includes offenses.first.message, "Rename `extract_title` to `title`"
  end

  test "allows a name whose method asks a collaborator it just built" do
    assert_no_offense <<~RUBY
      def create_system_comment_for(event)
        SystemCommenter.new(self, event).comment
      end
    RUBY
  end

  test "reports a factory that only hands the built value back" do
    offenses = assert_offense <<~RUBY
      def build_money(cents)
        Money.new(cents, currency)
      end
    RUBY

    assert_includes offenses.first.message, "Rename `build_money`"
  end

  test "allows a producer name on a method that assigns a field" do
    assert_no_offense <<~RUBY
      class Report
        def build_total
          @total = items.sum
        end
      end
    RUBY
  end

  test "allows a producer name on a method that writes records in bulk" do
    assert_no_offense <<~RUBY
      def create_archived_users
        User.insert_all(archive_rows)
      end
    RUBY
  end

  test "allows a producer name on a safely navigated mutation" do
    assert_no_offense <<~RUBY
      def create_user
        user&.save!
      end
    RUBY
  end

  test "allows a producer name on a method that yields or delegates to super" do
    assert_no_offense <<~RUBY
      def build_report
        yield
      end

      def load_account
        super
      end
    RUBY
  end

  test "allows a producer name on a method that invokes a subprocess" do
    assert_no_offense <<~RUBY
      def load_status
        `status --short`
      end
    RUBY
  end

  test "allows a producer name on a method that performs network IO" do
    assert_no_offense <<~RUBY
      def fetch_status
        Net::HTTP.get(status_uri)
      end
    RUBY
  end

  test "allows a producer name on a method that performs IO through an absolute constant" do
    assert_no_offense <<~RUBY
      def fetch_status
        ::Net::HTTP.get(status_uri)
      end

      def load_configuration
        ::File.read(path)
      end
    RUBY
  end

  test "allows a producer name on a method that performs filesystem IO" do
    assert_no_offense <<~RUBY
      def load_configuration
        File.read(path)
      end
    RUBY
  end
end
