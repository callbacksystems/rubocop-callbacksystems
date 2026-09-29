require "test_helper"

class RuboCop::Callbacksystems::Methods::StatementDefinitionsTest < ActiveSupport::TestCase
  include SourceParsing

  test "names returns an explicitly defined method" do
    assert_equal Set[:total], names_defined_by("def total; end")
  end

  test "names returns the methods defined by a prefixed delegate" do
    assert_equal Set[:user_name], names_defined_by("delegate :name, to: :user, prefix: true")
  end

  test "names returns the method defined by a scope" do
    assert_equal Set[:active], names_defined_by("scope :active, -> { all }")
  end

  test "names returns nil for a dynamically named scope" do
    assert_nil names_defined_by("scope scope_name, -> { all }")
  end

  test "names returns nil for a scope without a name" do
    assert_nil names_defined_by("scope")
  end

  test "names returns reader and writer methods from an accessor declaration" do
    assert_equal Set[:name, :name=], names_defined_by("attr_accessor :name")
  end

  test "names returns the exact methods from reader and writer declarations" do
    assert_equal Set[:name], names_defined_by("attr_reader :name")
    assert_equal Set[:name=], names_defined_by("attr_writer :name")
  end

  test "names returns nil when any accessor name is dynamic" do
    assert_nil names_defined_by("attr_accessor :name, other_name")
  end

  test "names returns nil for framework declarations whose complete method set is not statically known" do
    [
      "attribute :name, :string", "class_attribute :name", "has_secure_password", "has_secure_token",
      "belongs_to :account"
    ].each { assert_nil names_defined_by(it) }
  end

  test "names returns nothing for a macro that defines no known method" do
    assert_empty names_defined_by("validates :name, presence: true")
  end

  private
    def names_defined_by(source)
      RuboCop::Callbacksystems::Methods::StatementDefinitions.new(processed_source(source).ast).names
    end
end
