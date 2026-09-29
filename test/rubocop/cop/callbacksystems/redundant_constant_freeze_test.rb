require "test_helper"

class RuboCop::Cop::Callbacksystems::RedundantConstantFreezeTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::RedundantConstantFreeze

  test "registers offense for a frozen array constant" do
    assert_offense <<~RUBY
      FORMATS = [ :json ].freeze
    RUBY
  end

  test "registers offense for a frozen string constant" do
    assert_offense <<~RUBY
      TIMEOUT = "30s".freeze
    RUBY
  end

  test "registers offense for a frozen constant under a namespace" do
    assert_offense <<~RUBY
      Report::FORMATS = [ :json ].freeze
    RUBY
  end

  test "registers offense for a frozen constant inside a class" do
    assert_offense <<~RUBY
      class Report
        FORMATS = [ :json ].freeze
      end
    RUBY
  end

  test "autocorrects by removing the freeze" do
    assert_correction "FORMATS = [ :json ].freeze\n", "FORMATS = [ :json ]\n"
  end

  test "autocorrects a frozen call chain" do
    assert_correction "NAMES = Source.all.map(&:name).freeze\n", "NAMES = Source.all.map(&:name)\n"
  end

  test "autocorrects freeze with empty parentheses" do
    assert_correction "FORMATS = [ :json ].freeze()\n", "FORMATS = [ :json ]\n"
  end

  test "autocorrects a freeze wrapped in parentheses" do
    assert_correction "FORMATS = ([ :json ].freeze)\n", "FORMATS = ([ :json ])\n"
  end

  test "autocorrects a safe navigation freeze" do
    assert_correction "FORMATS = formats&.freeze\n", "FORMATS = formats\n"
  end

  test "does not offer correction when the freeze syntax contains a comment" do
    assert_uncorrectable_offense <<~RUBY
      FORMATS = formats.freeze( # Keep the reason attached to this call.
      )
    RUBY
  end

  test "does not offer correction when the freeze syntax contains a tooling comment" do
    assert_uncorrectable_offense <<~RUBY
      FORMATS = formats.freeze( # :nocov:
      )
    RUBY
  end

  test "leaves its correction at a fixed point" do
    assert_no_correction "FORMATS = [ :json ]\n"
  end

  test "does not register offense for a constant that freezes nothing" do
    assert_no_offense <<~RUBY
      FORMATS = [ :json ]
    RUBY
  end

  test "does not register offense for an empty parenthesized constant value" do
    assert_no_offense "FORMATS = ()\n"
  end

  test "does not register offense for a frozen instance variable" do
    assert_no_offense <<~RUBY
      @formats = [ :json ].freeze
    RUBY
  end

  test "does not register offense for a freeze outside an assignment" do
    assert_no_offense <<~RUBY
      formats.freeze
    RUBY
  end

  test "does not treat a receiverless freeze call as a redundant modifier" do
    assert_no_offense <<~RUBY
      FORMATS = freeze
    RUBY
  end
end
