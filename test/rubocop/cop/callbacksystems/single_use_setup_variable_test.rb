require "test_helper"

class RuboCop::Cop::Callbacksystems::SingleUseSetupVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SingleUseSetupVariable

  test "allows a source with no syntax tree" do
    assert_no_offense ""
  end

  test "setup assignments exposes its enumeration when no block is given" do
    source = RuboCop::ProcessedSource.new("@order = orders(:one)", RUBY_VERSION.to_f)
    assignments = self.class.cop_class::SetupAssignments.new(source.ast)

    assert_kind_of Enumerator, assignments.each
  end

  test "instance variable usages index each domain collection once" do
    ast = RuboCop::ProcessedSource.new(<<~RUBY, RUBY_VERSION.to_f).ast
      test "first" do
        use(@single, @shared)
      end

      test "second" do
        use(@shared)
      end
    RUBY
    reads = ast.each_node(:ivar).to_a
    tests = ast.each_node(:any_block).select { it.method?(:test) }
    read_enumerations = 0
    test_enumerations = 0
    indexed_reads = Enumerator.new do |yielder|
      read_enumerations += 1
      reads.each { yielder << it }
    end
    indexed_tests = Enumerator.new do |yielder|
      test_enumerations += 1
      tests.each { yielder << it }
    end

    usages = self.class.cop_class::InstanceVariableUsages.new(indexed_reads, tests: indexed_tests)

    assert usages.for(:@single).single_use?
    assert_not usages.for(:@shared).single_use?
    assert_same reads.first, usages.for(:@single).sole_direct_read
    assert_equal 1, read_enumerations
    assert_equal 1, test_enumerations
  end

  test "registers offense for setup instance variable used in only one test" do
    offenses = assert_offense <<~RUBY, count: 1, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_includes offenses.first.message, "@order"
  end

  test "no offense when setup variable is used in multiple tests" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "order has items" do
          assert @order.items.any?
        end
      end
    RUBY
  end

  test "no offense when setup has no instance variables" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          travel_to Time.zone.now
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "registers offense for each single-use variable independently" do
    assert_offense <<~RUBY, count: 2, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY
  end

  test "registers offense for variable used in zero tests" do
    offenses = assert_offense <<~RUBY, count: 1, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "something" do
          assert true
        end
      end
    RUBY

    assert_includes offenses.first.message, "@order"
    assert_includes offenses.first.message, "not used"
  end

  test "handles multiple setup blocks" do
    assert_offense <<~RUBY, count: 2, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        setup do
          @user = users(:john)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY
  end

  test "keeps same-named variables isolated between test classes" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @record = orders(:one)
        end

        test "reads the order" do
          assert @record.valid?
        end
      end

      class UserTest < ActiveSupport::TestCase
        setup do
          @record = users(:john)
        end

        test "reads the user" do
          assert @record.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "reads the order" do
          assert orders(:one).valid?
        end
      end

      class UserTest < ActiveSupport::TestCase
        test "reads the user" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_offense original, count: 2, file: "test/models/records_test.rb"
    assert_correction original, corrected, file: "test/models/records_test.rb"
  end

  test "keeps differently named variables within their own test classes" do
    assert_offense <<~RUBY, count: 2, file: "test/models/records_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup { @order = orders(:one) }

        test "reads the order" do
          assert @order.valid?
        end
      end

      class UserTest < ActiveSupport::TestCase
        setup { @user = users(:john) }

        test "reads the user" do
          assert @user.valid?
        end
      end
    RUBY
  end

  test "keeps same-named variables isolated between an outer test class and an anonymous test class" do
    original = <<~RUBY
      class RecordsTest < ActiveSupport::TestCase
        setup do
          @record = orders(:one)
        end

        test "reads the outer record" do
          assert @record.valid?
        end

        HandlerTest = Class.new(ActiveSupport::TestCase) do
          setup do
            @record = users(:john)
          end

          test "reads the handler record" do
            assert @record.valid?
          end
        end
      end
    RUBY
    corrected = <<~RUBY
      class RecordsTest < ActiveSupport::TestCase
        test "reads the outer record" do
          assert orders(:one).valid?
        end

        HandlerTest = Class.new(ActiveSupport::TestCase) do
          test "reads the handler record" do
            assert users(:john).valid?
          end
        end
      end
    RUBY

    assert_offense original, count: 2, file: "test/models/records_test.rb"
    assert_correction original, corrected, file: "test/models/records_test.rb"
  end

  test "does not attribute reads across nested class-like boundaries" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        class Helper
          def order
            @order
          end
        end

        Builder = Class.new do
          def order
            @order
          end
        end

        test "reads the test order" do
          assert @order.valid?
        end
      end
    RUBY
    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        class Helper
          def order
            @order
          end
        end

        Builder = Class.new do
          def order
            @order
          end
        end

        test "reads the test order" do
          assert orders(:one).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "does not attribute setup assignments in self-rebinding blocks to the test instance" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          Class.new { @order = orders(:one) }
          target.instance_eval { @user = users(:john) }
        end

        test "reads unrelated instance state" do
          assert @order
          assert @user
        end
      end
    RUBY
  end

  test "does not count a read in another self as use of setup state" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = nil
        end

        test "builds a handler" do
          Class.new { @order }
        end
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        test "builds a handler" do
          Class.new { @order }
        end
      end
    CORRECTED
  end

  test "keeps setup state in ordinary blocks and evaluation against self" do
    assert_offense <<~RUBY, count: 2, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          items.each { @order = orders(:one) }
          self.instance_eval { @user = users(:john) }
        end

        test "reads state" do
          assert @order
          assert @user
        end
      end
    RUBY
  end

  test "allows a variable assigned by more than one setup in the same class" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        setup do
          @order = orders(:two)
        end

        test "reads the order" do
          assert @order.valid?
        end
      end
    RUBY
  end

  test "does not flag an instance variable used via a helper method called from tests" do
    assert_no_offense <<~RUBY, file: "test/models/user_test.rb"
      class UserTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "is admin" do
          assert_admin
        end

        test "is active" do
          assert_admin
        end

        private
          def assert_admin
            assert @user.admin?
          end
      end
    RUBY
  end

  test "skips abstract test base classes that directly inherit Rails test bases" do
    assert_no_offense <<~RUBY, file: "test/integration_test.rb"
      class IntegrationTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:admin)
        end
      end
    RUBY
  end

  test "skips an abstract base without hiding a concrete class later in the file" do
    source = <<~RUBY
      class IntegrationTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:admin)
        end
      end

      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "reads the order" do
          assert @order.valid?
        end
      end
    RUBY

    offenses = assert_offense source, count: 1, file: "test/integration_test.rb"

    assert_includes offenses.first.message, "@order"
  end

  test "skips an abstract base after processing a concrete class" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "reads the order" do
          assert @order.valid?
        end
      end

      class IntegrationTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:admin)
        end
      end
    RUBY

    offenses = assert_offense source, count: 1, file: "test/integration_test.rb"

    assert_includes offenses.first.message, "@order"
  end

  test "ignores assignments inside deferred callables built in setup" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          callback = -> { @order = orders(:one) }
          proc { @user = users(:john) }
          Proc.new { @account = accounts(:main) }
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "ignores assignments inside method definitions written in setup" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          def callback
            @order = orders(:one)
          end

          def self.other_callback
            @user = users(:john)
          end
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "ignores assignments inside dynamically defined methods written in setup" do
    assert_no_offense <<~RUBY, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          define_method(:callback) { @order = orders(:one) }
          object.define_singleton_method(:other_callback) { @user = users(:john) }
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "finds assignments evaluated in definition headers" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          def (@method_host = Object.new).callback
          end

          class << (@singleton_host = Object.new)
          end
        end

        test "something" do
          assert true
        end
      end
    RUBY

    offenses = assert_offense source, count: 2, file: "test/models/order_test.rb"

    assert_equal [ :unsupported, :unsupported ], offenses.map(&:status)
  end

  test "finds an assignment nested deeper than the Ruby call stack" do
    assignment = RuboCop::ProcessedSource.new("@order = 1\n", RUBY_VERSION.to_f).ast
    body = 2_000.times.reduce(assignment) do |nested, _index|
      RuboCop::AST::Node.new(:begin, [ nested ])
    end

    assert_equal [ assignment ], RuboCop::Cop::Callbacksystems::SingleUseSetupVariable::SetupAssignments.new(body).to_a
  end

  test "reports without inlining an assignment nested in an ordinary setup block" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          with_context { @order = orders(:one) }
        end

        test "reads the order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "does not flag an instance variable used elsewhere in the same setup block" do
    assert_no_offense <<~RUBY, file: "test/cli_test.rb"
      class CliTest < ActiveSupport::TestCase
        setup do
          @secrets_dir = Dir.mktmpdir
          PGBOX.stubs(:secrets_path).returns(File.join(@secrets_dir, ".pgbox/secrets"))
          FileUtils.mkdir_p(File.join(@secrets_dir, ".pgbox"))
        end

        teardown do
          FileUtils.rm_rf(@secrets_dir)
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "autocorrects a single-use variable by inlining it and removing the setup block" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order is valid" do
          assert orders(:one).valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "leaves a single-use heredoc in setup rather than detaching its body" do
    assert_uncorrectable_offense <<~RUBY, file: "test/models/message_test.rb"
      class MessageTest < ActiveSupport::TestCase
        setup do
          @message = <<~TEXT
            hello
          TEXT
        end

        test "message has content" do
          assert_equal "hello\\n", @message
        end
      end
    RUBY
  end

  test "leaves an unused heredoc beside other setup work rather than detaching its body" do
    assert_uncorrectable_offense <<~RUBY, file: "test/models/message_test.rb"
      class MessageTest < ActiveSupport::TestCase
        setup do
          @message = <<~TEXT
            hello
          TEXT
          prepare
        end

        test "something" do
          assert true
        end
      end
    RUBY
  end

  test "autocorrects an unused variable without dropping the work of its value" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
          configure_factory
        end

        test "something" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          orders(:one)
          configure_factory
        end

        test "something" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "removes a setup block when every unused assignment holds only a literal" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @unused = 1
        end

        test "something" do
          assert true
        end
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        test "something" do
          assert true
        end
      end
    CORRECTED
  end

  test "removes a setup block directly above the next statement" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @unused = 1
        end
        test "something" do
          assert true
        end
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        test "something" do
          assert true
        end
      end
    CORRECTED
  end

  test "removes a cleared setup before another statement on its line" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup { @unused = 1 }; test("works") { assert true }
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        test("works") { assert true }
      end
    CORRECTED
  end

  test "removes a cleared setup without deleting the statement before it on the line" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        register; setup { @unused = 1 }

        test("works") { assert true }
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        register

        test("works") { assert true }
      end
    CORRECTED
  end

  test "removes a same-line literal assignment without deleting the setup work beside it" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "test/models/order_test.rb"
      class OrderTest < ActiveSupport::TestCase
        setup do
          @unused = 1; prepare
        end

        test "something" do
          assert true
        end
      end
    RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          prepare
        end

        test "something" do
          assert true
        end
      end
    CORRECTED
  end

  test "autocorrects a single-use variable while keeping a setup block with other statements" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          travel_to Time.zone.now
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          travel_to Time.zone.now
        end

        test "order is valid" do
          assert orders(:one).valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects single-use variables across multiple setup blocks" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @name = "Order"
        end

        setup do
          @user = users(:john)
        end

        test "order has a name" do
          assert_equal "Order", @name
        end

        test "user is valid" do
          assert @user.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order has a name" do
          assert_equal "Order", "Order"
        end

        test "user is valid" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "autocorrects every variable in a setup block without leaving it empty" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @name = "Order"
          @role = :admin
        end

        test "order has a name" do
          assert_equal "Order", @name
        end

        test "user has a role" do
          assert_equal :admin, @role
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        test "order has a name" do
          assert_equal "Order", "Order"
        end

        test "user has a role" do
          assert_equal :admin, :admin
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "removes only the cleared lines when one variable in the setup block stays" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "user is valid" do
          assert @user.valid?
          assert @user.persisted?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @user = users(:john)
        end

        test "order is valid" do
          assert orders(:one).valid?
        end

        test "user is valid" do
          assert @user.valid?
          assert @user.persisted?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "keeps a tooling-protected assignment while safely correcting an independent one" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          # :nocov:
          # :nocov:
          @order = orders(:one)
          @user = users(:john)
        end

        test "reads order" do
          assert @order.valid?
        end

        test "reads user" do
          assert @user.valid?
        end
      end
    RUBY

    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          # :nocov:
          # :nocov:
          @order = orders(:one)
        end

        test "reads order" do
          assert @order.valid?
        end

        test "reads user" do
          assert users(:john).valid?
        end
      end
    RUBY

    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "leaves setup-wide tooling in place rather than emptying its callback" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        # :nocov:
        setup do
          @order = orders(:one)
        end

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a setup local into the test scope" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          order = orders(:one)
          @order = decorate(order)
        end

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without inlining a call whose unparenthesized arguments would bind differently" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = factory.build :order
        end

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without making a setup call conditional" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        test "reads order" do
          assert @order.valid? if enabled?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a setup call into a lazy expression" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        test "reads order" do
          @order && assert_ready
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a call past a later setup statement" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
          configure_factory
        end

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a call past a later setup callback" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        setup do
          configure_factory
        end

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a call past a later named setup callback" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        setup :configure_factory

        test "reads order" do
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a call past earlier test work" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        test "reads order" do
          prepare_assertion
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "reports without moving a call past an earlier evaluation in the same statement" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = build_order
        end

        test "reads order" do
          assert_equal expected_order, @order
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "autocorrects only the trailing call when reversed reads would invert setup order" do
    original = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @first = build_first
          @second = build_second
        end

        test "reads both" do
          assert @second.valid?
          assert @first.valid?
        end
      end
    RUBY
    corrected = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @first = build_first
        end

        test "reads both" do
          assert build_second.valid?
          assert @first.valid?
        end
      end
    RUBY

    offenses = assert_offense original, count: 2, file: "test/models/order_test.rb"

    assert_equal :unsupported, offenses.first.status
    assert_correction original, corrected, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the value is not a primary expression" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one) || build_order
        end

        test "order is valid" do
          assert @order.valid?
        end

        test "something else" do
          assert true
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the variable is referenced more than once in the test" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          assert @order.valid?
          assert @order.persisted?
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end

  test "reports without inlining a setup value overwritten before its sole read" do
    source = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "order is valid" do
          @order = orders(:two)
          assert @order.valid?
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/order_test.rb"
  end

  test "does not autocorrect when the reference is inside an iterator" do
    code = <<~RUBY
      class OrderTest < ActiveSupport::TestCase
        setup do
          @order = orders(:one)
        end

        test "touches the order" do
          3.times { @order.touch }
        end
      end
    RUBY

    assert_offense code, file: "test/models/order_test.rb"
    assert_correction code, code, file: "test/models/order_test.rb"
  end
  test "allows variables assigned together in one multiple assignment" do
    assert_no_offense <<~RUBY, file: "test/models/topic_test.rb"
      class TopicTest < ActiveSupport::TestCase
        setup do
          @first, @second, @third = topics(:one, :two, :three)
        end

        test "reads the first" do
          assert @first.valid?
        end
      end
    RUBY
  end

  test "registers offense for a setup block shared through a module" do
    assert_offense <<~RUBY, count: 1, file: "test/models/concerns/order_tests.rb"
      module OrderTests
        extend ActiveSupport::Concern

        included do
          setup do
            @order = orders(:one)
          end

          test "order is valid" do
            assert @order.valid?
          end

          test "something else" do
            assert true
          end
        end
      end
    RUBY
  end

  test "keeps a concern setup variable read by a helper outside its included block" do
    assert_no_offense <<~RUBY, file: "test/models/concerns/order_tests.rb"
      module OrderTests
        extend ActiveSupport::Concern

        included do
          setup do
            @order = build_order
          end

          test "order is valid" do
            assert_order
          end
        end

        private
          def assert_order
            assert @order.valid?
          end
      end
    RUBY
  end

  test "keeps an anonymous concern setup variable read by a helper outside its included block" do
    assert_no_offense <<~RUBY, file: "test/models/concerns/order_tests.rb"
      OrderTests = Module.new do
        extend ActiveSupport::Concern

        included do
          setup do
            @order = build_order
          end

          test "order is valid" do
            assert_order
          end
        end

        private
          def assert_order
            assert @order.valid?
          end
      end
    RUBY
  end

  test "reports a concern without moving a call past its later named setup callback" do
    source = <<~RUBY
      module OrderTests
        extend ActiveSupport::Concern

        included do
          setup do
            @order = build_order
          end

          setup :configure_factory

          test "order is valid" do
            assert @order.valid?
          end
        end
      end
    RUBY

    assert_uncorrectable_offense source, file: "test/models/concerns/order_tests.rb"
  end

  test "still reports a plain assignment beside a multiple one" do
    assert_offense <<~RUBY, count: 1, file: "test/models/topic_test.rb"
      class TopicTest < ActiveSupport::TestCase
        setup do
          @topic = topics(:one)
          @first, @second = contacts(:one, :two)
        end

        test "reads the topic" do
          assert @topic.valid?
        end
      end
    RUBY
  end
end
