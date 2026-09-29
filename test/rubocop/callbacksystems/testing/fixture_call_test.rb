require "test_helper"

class RuboCop::Callbacksystems::Testing::FixtureCallTest < ActiveSupport::TestCase
  test "valid? returns true for a fixture set the project declares" do
    fixture_call = fixture_call_for("users(:john)")

    assert fixture_call.valid?
  end

  test "valid? returns true for the other sets the project declares" do
    %w[ accounts orders items posts comments ].each do |method|
      fixture_call = fixture_call_for("#{method}(:name)")

      assert fixture_call.valid?, "Expected #{method}(:name) to be valid"
    end
  end

  test "valid? returns true for a set nested in a directory" do
    assert fixture_call_for("webhook_deliveries(:one)").valid?
  end

  test "valid? returns false for a test helper that reads like a fixture call" do
    assert_not fixture_call_for("sign_in_as(:john)").valid?
  end

  test "valid? returns false for a pluralized name the project declares no fixtures for" do
    assert_not fixture_call_for("widgets(:john)").valid?
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

  test "valid? returns false for a source outside a test tree" do
    assert_not fixture_call_for("users(:john)", file: "app/models/user.rb").valid?
  end

  test "valid? returns false for nil node" do
    fixture_call = RuboCop::Callbacksystems::Testing::FixtureCall.new(nil)

    assert_not fixture_call.valid?
  end

  test "signature returns method name with symbol" do
    fixture_call = fixture_call_for("users(:john)")

    assert_equal "users(:john)", fixture_call.signature
  end

  test "signature returns correct value for various fixtures" do
    {
      "accounts(:callback)" => "accounts(:callback)",
      "orders(:first)" => "orders(:first)",
      "items(:product)" => "items(:product)"
    }.each do |source, expected|
      fixture_call = fixture_call_for(source)

      assert_equal expected, fixture_call.signature
    end
  end

  test "signature preserves the source spelling of a quoted symbol" do
    fixture_call = fixture_call_for('users(:"john-doe")')

    assert_equal 'users(:"john-doe")', fixture_call.signature
  end

  test "identity gives equivalent symbol spellings the same fixture identity" do
    plain = fixture_call_for("users(:john)")
    quoted = fixture_call_for('users(:"john")')

    assert_equal plain.identity, quoted.identity
  end

  test "node accessor returns the original node" do
    node = NodeParser.new("users(:john)", "test/example_test.rb").send_node
    fixture_call = RuboCop::Callbacksystems::Testing::FixtureCall.new(node)

    assert_equal node, fixture_call.node
  end

  private
    def fixture_call_for(source, file: "test/example_test.rb")
      node = NodeParser.new(source, file).send_node

      RuboCop::Callbacksystems::Testing::FixtureCall.new(node)
    end

    class NodeParser
      def initialize(source, file)
        @source = source
        @file = file
      end

      def send_node
        ast.send_type? ? ast : descendant_send_node(ast)
      end

      private
        attr_reader :source, :file

        def ast
          RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file).ast
        end

        def descendant_send_node(node)
          node.each_descendant(:send).first
        end
    end
end
