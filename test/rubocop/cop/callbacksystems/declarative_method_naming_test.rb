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
    offenses = assert_offense <<~RUBY
      def compute_total
        a + b
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `compute_total` to `total`"
    assert_includes offenses.first.message, "not the action `compute`"
  end

  test "registers offense for producer verb with arguments, asking to relate to the argument" do
    offenses = assert_offense <<~RUBY
      def get_user(id)
        users[id]
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `get_user` for the value, related to its argument"
    assert_includes offenses.first.message, "not the action `get`"
  end

  test "registers offense for a class method named with a producer verb" do
    offenses = assert_offense <<~RUBY
      def self.parse_config(text)
        JSON.parse(text)
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `parse_config` for the value, related to its argument"
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

  test "registers offense for a producer verb followed by a connector, with no suggestion" do
    offenses = assert_offense <<~RUBY
      def find_in_scope
        scope.lookup
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `find_in_scope`: it names the imperative `find` action"
  end

  test "registers offense suggesting the noun when the noun already carries a connector" do
    offenses = assert_offense <<~RUBY
      def get_user_by_id(id)
        users[id]
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `get_user_by_id` to `user_by_id`"
    assert_includes offenses.first.message, "not the action `get`"
  end

  test "subsumes the old extract naming smell" do
    offenses = assert_offense <<~RUBY
      def extract_title
        node.title
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Rename `extract_title` to `title`"
  end
end
