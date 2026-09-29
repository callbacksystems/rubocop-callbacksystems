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

  test "registers abbreviations before method punctuation" do
    assert_offense <<~RUBY, count: 3
      def attrs?
      end

      def calc!
      end

      def msg=(value)
      end
    RUBY
  end

  test "registers and underlines every abbreviation in one name" do
    offenses = assert_offense <<~RUBY, count: 2
      def msg_attrs?
      end
    RUBY

    assert_equal %w[ msg attrs ], offenses.map { it.location.source }
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

  test "registers offense for stmt variable" do
    assert_offense <<~RUBY
      def process
        stmt = statements.first
      end
    RUBY
  end

  test "registers offense for an abbreviated pattern variable" do
    assert_offense <<~RUBY
      case payload
      in { message: msg }
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

  test "registers offenses for abbreviated variadic arguments" do
    assert_offense <<~RUBY, count: 3
      def process(*vals, **opts, &proc_var)
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

  test "registers offense for global variable" do
    assert_offense <<~RUBY
      $msg = "failure"
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

  test "registers offense for an abbreviated class variable" do
    assert_offense <<~RUBY
      class Report
        @@err = nil
      end
    RUBY
  end

  test "registers offense for an abbreviated shadow argument" do
    assert_offense <<~RUBY
      records.each { |;msg| consume(msg) }
    RUBY
  end

  test "registers abbreviations in CamelCase class module and assigned constant names" do
    offenses = assert_offense <<~RUBY, count: 3
      class UserAttrs
      end

      module MsgHandlers
      end

      PackedOpts = Class.new
    RUBY

    assert_equal %w[ Attrs Msg Opts ], offenses.map { it.location.source }
    assert_includes offenses.first.message, "Avoid abbreviation `Attrs`. Use `Attributes` instead."
  end

  test "checks only the final declared segment of a qualified class or module" do
    offenses = assert_offense <<~RUBY, count: 2
      class External::Attrs::UserMsg < External::Obj
      end

      module ::External::Opts::CurrentCtx
      end
    RUBY

    assert_equal %w[ Msg Ctx ], offenses.map { it.location.source }
  end

  test "leaves references calls and literal keys belonging to external APIs alone" do
    assert_no_offense <<~RUBY
      External::Attrs.new
      third_party.parse_msg(user_opts)
      payload = { msg: :err }

      def process(value = External::Cfg)
      end
    RUBY
  end

  test "recognizes word boundaries in camelCase methods variables and parameters" do
    offenses = assert_offense <<~RUBY, count: 5
      def buildMsg(userAttrs, fallbackOpts: nil)
        localCtx = userAttrs
        @savedMsg = localCtx
      end
    RUBY

    assert_equal %w[ Msg Attrs Opts Ctx Msg ], offenses.map { it.location.source }
  end

  test "registers abbreviations in optional positional and keyword arguments" do
    offenses = assert_offense <<~RUBY, count: 2
      def process(msg = nil, err: nil)
      end
    RUBY

    assert_equal %w[ msg err ], offenses.map { it.location.source }
  end

  test "allows anonymous and forwarded arguments without a name range" do
    assert_no_offense <<~RUBY
      def process(*, **, &)
        consume(*, **, &)
      end

      def forward(...)
        consume(...)
      end
    RUBY
  end

  test "underlines abbreviations after sigils and unused parameter prefixes" do
    offenses = assert_offense <<~RUBY, count: 4
      class Report
        @@msg = nil
        @cached_opts = nil

        def process(_attrs)
        end
      end

      $err = nil
    RUBY

    assert_equal %w[ msg opts attrs err ], offenses.map { it.location.source }
  end

  test "keeps exact source ranges after multibyte text and inside multibyte identifiers" do
    offenses = assert_offense <<~RUBY, count: 3
      "é"; café_obj = nil
      @café_msg = nil
      class CaféAttrs
      end
    RUBY

    assert_equal %w[ obj msg Attrs ], offenses.map { it.location.source }
  end

  test "does not mistake whole Unicode words for abbreviations" do
    assert_no_offense <<~RUBY
      class Ström
      end

      class Érr
      end

      def café
      end
    RUBY
  end

  test "keeps acronym boundaries and the case of each suggested expansion" do
    offenses = assert_offense <<~RUBY, count: 3
      class HTTPMsgParser
      end

      XML_ATTRS = nil

      def api_msg
      end
    RUBY

    assert_equal %w[ Msg ATTRS msg ], offenses.map { it.location.source }
    assert_equal [
      "Avoid abbreviation `Msg`. Use `Message` instead.",
      "Avoid abbreviation `ATTRS`. Use `ATTRIBUTES` instead.",
      "Avoid abbreviation `msg`. Use `message` instead."
    ], messages_of(offenses)
  end

  test "leaves established acronyms and full words intact" do
    assert_no_offense <<~RUBY
      class XMLHTTPRequest
      end

      class MSGHTTPParser
      end

      class AttributeError
      end

      module FileUtils
      end

      def error_message(string, expression:, previous:)
      end
    RUBY
  end

  test "allows Ruby attribute API names in snake case and CamelCase" do
    assert_no_offense <<~RUBY
      def attr_reader_for(record)
      end

      class PreferAttrReaderOverInstanceVariable
      end

      class AttrWriter
      end

      module AttrAccessor
      end

      ATTR_ACCESSOR_KEYS = []
    RUBY
  end

  test "attribute API conventions do not excuse nearby or similarly named abbreviations" do
    offenses = assert_offense <<~RUBY, count: 4
      def attr_readerish
      end

      class AttrReaders
      end

      class AttrReaderOpts
      end

      attr = nil
    RUBY

    assert_equal %w[ attr Attr Opts attr ], offenses.map { it.location.source }
  end

  test "permits Ruby and Rails conventions without shortening complete names" do
    assert_no_offense <<~RUBY
      params, args, id, ids, config, env, info, lib, max, min, proc, procs, temp, sync = []
      application, configuration, repository = []

      class ApplicationConfig
      end

      class Repository
      end
    RUBY
  end

  test "does not assume expansions for ambiguous words or standard library names" do
    assert_no_offense <<~RUBY
      dir, mod, ext, prod, dist, dst, db, dev = []

      class Dir
      end

      class Proc
      end
    RUBY
  end

  test "recognizes common abbreviated collection and rendering names" do
    offenses = assert_offense <<~RUBY, count: 7
      def render_btn(elem, elems:, buf:, cb:)
        arr = []
        curr = elem
      end
    RUBY

    assert_equal %w[ btn elem elems buf cb arr curr ], offenses.map { it.location.source }
  end

  test "expands abbreviated configuration names into complete words" do
    offenses = assert_offense <<~RUBY, count: 3
      def load_cfg(conf, ctx:)
      end
    RUBY

    assert_equal [
      "Avoid abbreviation `cfg`. Use `configuration` instead.",
      "Avoid abbreviation `conf`. Use `configuration` instead.",
      "Avoid abbreviation `ctx`. Use `context` instead."
    ], messages_of(offenses)
  end

  test "recognizes abbreviated analysis and dependency names" do
    offenses = assert_offense <<~RUBY, count: 9
      def resolve_decl(decls, dep:, deps:, ident:, idents:, idx:, exprs:, len:)
      end
    RUBY

    assert_equal %w[ decl decls dep deps ident idents idx exprs len ], offenses.map { it.location.source }
  end

  test "recognizes abbreviated command event and metadata names" do
    offenses = assert_offense <<~RUBY, count: 6
      def execute_cmd(evt, perf:, sep:, tbl:, ver:)
      end
    RUBY

    assert_equal %w[ cmd evt perf sep tbl ver ], offenses.map { it.location.source }
  end

  test "offers alternatives when an existing abbreviation has multiple meanings" do
    offenses = assert_offense <<~RUBY, count: 2
      res = nil
      API_DOCS = nil
    RUBY

    assert_equal [
      "Avoid abbreviation `res`. Use `resource` or `response` or `result` instead.",
      "Avoid abbreviation `DOCS`. Use `DOCUMENTATION` or `DOCUMENTS` instead."
    ], messages_of(offenses)
  end

  test "leaves renaming to the author because references may live outside the current source" do
    assert_uncorrectable_offense <<~RUBY
      class UserAttrs
      end
    RUBY
  end

  private
    def messages_of(offenses)
      offenses.map { it.message.delete_prefix("#{it.cop_name}: ") }
    end
end
