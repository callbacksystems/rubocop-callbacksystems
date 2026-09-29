require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::StatementRankTest < ActiveSupport::TestCase
  include SourceParsing

  Rank = RuboCop::Callbacksystems::ClassStructure::StatementRank

  test "to_i reads a mixin as MIXIN" do
    assert_equal Rank::MIXIN, rank_of("include Printable")
  end

  test "to_i reads a class attribute assigned on self as MIXIN" do
    assert_equal Rank::MIXIN, rank_of('self.table_name = "reports"')
  end

  test "to_i reads a screaming snake case constant as VALUE" do
    assert_equal Rank::VALUE, rank_of("COLUMNS = fetch_columns")
  end

  test "to_i reads a constant named like a class as CLASS_DECLARATION" do
    assert_equal Rank::CLASS_DECLARATION, rank_of("Row = Data.define(:name)")
  end

  test "to_i reads an attribute macro as ATTRIBUTE" do
    assert_equal Rank::ATTRIBUTE, rank_of("attr_reader :rows")
    assert_equal Rank::ATTRIBUTE, rank_of("has_secure_password")
  end

  test "to_i reads an association as ASSOCIATION" do
    assert_equal Rank::ASSOCIATION, rank_of("belongs_to :board")
  end

  test "to_i reads a delegate as DELEGATE" do
    assert_equal Rank::DELEGATE, rank_of("delegate :name, to: :board")
  end

  test "to_i reads any other bare call as MACRO" do
    assert_equal Rank::MACRO, rank_of("validates :name, presence: true")
  end

  test "to_i reads a method as METHOD" do
    assert_equal Rank::METHOD, rank_of("def total; end")
    assert_equal Rank::METHOD, rank_of("def self.total; end")
  end

  test "to_i reads a statement that is no declaration as METHOD" do
    assert_equal Rank::METHOD, rank_of("Rails.logger.info(:loaded)")
  end

  test "to_i reads a class or module with a body as NESTED_CLASS" do
    assert_equal Rank::NESTED_CLASS, rank_of("class Row; def name; end; end")
    assert_equal Rank::NESTED_CLASS, rank_of("module Formatting; def label; end; end")
  end

  test "to_i reads a class builder given a block as NESTED_CLASS" do
    assert_equal Rank::NESTED_CLASS, rank_of("Row = Data.define(:name) do; def to_s; end; end")
    assert_equal Rank::NESTED_CLASS, rank_of("Formatting = Module.new do; def to_s; end; end")
  end

  test "to_i reads a namespaced builder lookalike as an ordinary class-named constant" do
    assert_equal Rank::CLASS_DECLARATION, rank_of(<<~RUBY)
      Row = Domain::Data.define(:name) do
        def to_s; end
      end
    RUBY
  end

  test "to_i reads an empty builder block as a class declaration" do
    assert_equal Rank::CLASS_DECLARATION, rank_of("Row = Data.define(:name) {}")
    assert_equal Rank::CLASS_DECLARATION, rank_of("Formatting = Module.new { # marker\n}")
  end

  test "to_i reads through a modifier condition around the statement" do
    assert_equal Rank::MIXIN, rank_of("include Detection if Rails.env.local?")
    assert_equal Rank::MIXIN, rank_of("include Detection unless Rails.env.production?")
  end

  test "to_i reads a macro given a block as the macro" do
    assert_equal Rank::ASSOCIATION, rank_of("has_many :blocks do; def published; end; end")
    assert_equal Rank::MACRO, rank_of("scope :recent do; order(id: :desc); end")
  end

  test "to_i gives private_constant the rank of the constant it hides" do
    statements = statements_of(<<~RUBY)
      Row = Data.define(:name)
      private_constant :Row
    RUBY

    assert_equal Rank::CLASS_DECLARATION, Rank.new(statements.last, statements).to_i
  end

  test "to_i gives private_constant the highest rank among the constants it hides" do
    statements = statements_of(<<~RUBY)
      LIMIT = 10
      Row = Data.define(:name)
      private_constant :LIMIT, :Row
    RUBY

    assert_equal Rank::CLASS_DECLARATION, Rank.new(statements.last, statements).to_i
  end

  test "to_i reads private_constant as VALUE when it names no constant of the body" do
    assert_equal Rank::VALUE, rank_of("private_constant :LIMIT")
  end

  private
    def rank_of(source)
      rank_for(source).to_i
    end

    def rank_for(source)
      statements = statements_of(source)
      Rank.new(statements.first, statements)
    end

    def statements_of(body)
      source = "class Report\n#{body}\nend\n"
      parsed = processed_source(source).ast.body
      parsed.begin_type? ? parsed.children : [ parsed ]
    end
end
