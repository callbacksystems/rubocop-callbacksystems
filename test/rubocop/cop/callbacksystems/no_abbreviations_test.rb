require "test_helper"

class RuboCop::Cop::Callbacksystems::NoAbbreviationsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAbbreviations

  test "registers offense for attrs in method name" do
    assert_offense <<~RUBY
      def user_attrs
      end
    RUBY
  end

  test "registers offense for calc in method name" do
    assert_offense <<~RUBY
      def calc_total
      end
    RUBY
  end

  test "registers offense for opts in variable" do
    assert_offense <<~RUBY
      def process
        opts = {}
      end
    RUBY
  end

  test "registers offense for tmp variable" do
    assert_offense <<~RUBY
      def process
        tmp = data.dup
      end
    RUBY
  end

  test "registers offense for msg in method argument" do
    assert_offense <<~RUBY
      def log(msg)
      end
    RUBY
  end

  test "registers offense for err in keyword argument" do
    assert_offense <<~RUBY
      def handle(err:)
      end
    RUBY
  end

  test "registers offense for instance variable" do
    assert_offense <<~RUBY
      def initialize
        @attrs = {}
      end
    RUBY
  end

  test "registers offense for constant with abbreviation" do
    assert_offense <<~RUBY
      USER_ATTRS = %i[name email]
    RUBY
  end

  test "registers offense for class method" do
    assert_offense <<~RUBY
      def self.calc_average
      end
    RUBY
  end

  test "allows full words" do
    assert_no_offense <<~RUBY
      def calculate_total
      end
    RUBY
  end

  test "allows attributes" do
    assert_no_offense <<~RUBY
      def user_attributes
      end
    RUBY
  end

  test "allows options" do
    assert_no_offense <<~RUBY
      def process
        options = {}
      end
    RUBY
  end

  test "allows params (Rails convention)" do
    assert_no_offense <<~RUBY
      def user_params
      end
    RUBY
  end

  test "allows args" do
    assert_no_offense <<~RUBY
      def call(*args)
      end
    RUBY
  end

  test "allows id and ids" do
    assert_no_offense <<~RUBY
      def find_by_id(id)
        user_ids = []
      end
    RUBY
  end

  test "allows config" do
    assert_no_offense <<~RUBY
      def load_config
        config = read_file
      end
    RUBY
  end

  test "allows env" do
    assert_no_offense <<~RUBY
      def current_env
        env = Rails.env
      end
    RUBY
  end

  test "allows info" do
    assert_no_offense <<~RUBY
      def user_info
        info = fetch_data
      end
    RUBY
  end

  test "allows lib" do
    assert_no_offense <<~RUBY
      def load_lib
        lib = external_library
      end
    RUBY
  end

  test "allows max and min" do
    assert_no_offense <<~RUBY
      def calculate
        max = values.max
        min = values.min
      end
    RUBY
  end

  test "allows proc" do
    assert_no_offense <<~RUBY
      def with_proc
        proc = -> { }
      end
    RUBY
  end

  test "allows temp" do
    assert_no_offense <<~RUBY
      def process
        temp = create_temp_file
      end
    RUBY
  end

  test "allows sync" do
    assert_no_offense <<~RUBY
      def sync_data
        sync = synchronizer.new
      end
    RUBY
  end

  test "registers offense for msg abbreviation in constants" do
    assert_offense <<~RUBY
      MSG = "Error message"
    RUBY
  end

  test "allows MESSAGE constant" do
    assert_no_offense <<~RUBY
      MESSAGE = "Error message"
      MESSAGE_ERROR = "Error"
    RUBY
  end

  test "registers offense for abbrev abbreviation" do
    assert_offense <<~RUBY
      def find_abbrev(text)
      end
    RUBY
  end

  test "registers offense for expr abbreviation" do
    assert_offense <<~RUBY
      def parse_expr(code)
      end
    RUBY
  end

  test "allows expression" do
    assert_no_offense <<~RUBY
      def parse_expression(code)
      end
    RUBY
  end

  test "allows abbreviation" do
    assert_no_offense <<~RUBY
      def find_abbreviation(text)
      end
    RUBY
  end
end
