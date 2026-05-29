require "test_helper"

class RuboCop::Callbacksystems::FixtureCallTest < ActiveSupport::TestCase
  test "valid? returns true for pluralized method with symbol argument" do
    fixture_call = fixture_call_for("users(:john)")

    assert fixture_call.valid?
  end

  test "valid? returns true for other pluralized fixture methods" do
    %w[accounts orders items posts comments].each do |method|
      fixture_call = fixture_call_for("#{method}(:name)")

      assert fixture_call.valid?, "Expected #{method}(:name) to be valid"
    end
  end

  test "valid? returns false for singular method name" do
    fixture_call = fixture_call_for("user(:john)")

    assert_not fixture_call.valid?
  end

  test "valid? returns false for method without symbol argument" do
    fixture_call = fixture_call_for("users(john)")

    assert_not fixture_call.valid?
  end

  test "valid? returns false for method with string argument" do
    fixture_call = fixture_call_for('users("john")')

    assert_not fixture_call.valid?
  end

  test "valid? returns false for method with multiple arguments" do
    fixture_call = fixture_call_for("users(:john, :jane)")

    assert_not fixture_call.valid?
  end

  test "valid? returns false for method with receiver" do
    fixture_call = fixture_call_for("self.users(:john)")

    assert_not fixture_call.valid?
  end

  test "valid? returns false for nil node" do
    fixture_call = RuboCop::Callbacksystems::FixtureCall.new(nil)

    assert_not fixture_call.valid?
  end

  test "signature returns method name with symbol" do
    fixture_call = fixture_call_for("users(:john)")

    assert_equal "users(:john)", fixture_call.signature
  end

  test "signature returns correct value for various fixtures" do
    { "accounts(:callback)" => "accounts(:callback)",
      "orders(:first)" => "orders(:first)",
      "items(:product)" => "items(:product)" }.each do |source, expected|
      fixture_call = fixture_call_for(source)

      assert_equal expected, fixture_call.signature
    end
  end

  test "node accessor returns the original node" do
    node = NodeParser.new("users(:john)").send_node
    fixture_call = RuboCop::Callbacksystems::FixtureCall.new(node)

    assert_equal node, fixture_call.node
  end

  private
    def fixture_call_for(source)
      node = NodeParser.new(source).send_node
      RuboCop::Callbacksystems::FixtureCall.new(node)
    end

    class NodeParser
      def initialize(source)
        @source = source
      end

      def send_node
        ast.send_type? ? ast : descendant_send_node(ast)
      end

      private
        attr_reader :source

        def ast
          RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
        end

        def descendant_send_node(node)
          node.each_descendant(:send).first
        end
    end
end
