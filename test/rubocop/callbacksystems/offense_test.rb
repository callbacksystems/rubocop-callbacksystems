require "test_helper"

class OffenseTest < ActiveSupport::TestCase
  include SourceParsing

  setup do
    @source = processed_source("total = 1")
    @corrector = RuboCop::Cop::Corrector.new(@source)
  end

  test "correction exposes the correction it was given" do
    correction = ->(corrector) { corrector.replace(@source.ast, "total = 2") }

    assert_same correction, RuboCop::Callbacksystems::Offense.new(@source.ast, "message", &correction).correction
  end

  test "correction is absent when no correction was given" do
    assert_nil RuboCop::Callbacksystems::Offense.new(@source.ast, "message").correction
  end

  test "correction is absent when the offense was built with correcting false" do
    offense = RuboCop::Callbacksystems::Offense.new(@source.ast, "message", correcting: false) { flunk }

    assert_nil offense.correction
  end

  test "correct runs the correction it was given" do
    offense = RuboCop::Callbacksystems::Offense.new(@source.ast, "message") { it.replace(@source.ast, "total = 2") }
    offense.correct(@corrector)

    assert_equal "total = 2", @corrector.process
  end

  test "correct adds nothing when no correction was given" do
    RuboCop::Callbacksystems::Offense.new(@source.ast, "message").correct(@corrector)

    assert_empty @corrector
  end

  test "correct adds nothing when the offense was built with correcting false" do
    offense = RuboCop::Callbacksystems::Offense.new(@source.ast, "message", correcting: false) do |corrector|
      corrector.replace(@source.ast, "total = 2")
    end
    offense.correct(@corrector)

    assert_empty @corrector
  end

  test "correct runs the correction when the offense was built with correcting true" do
    offense = RuboCop::Callbacksystems::Offense.new(@source.ast, "message", correcting: true) do |corrector|
      corrector.replace(@source.ast, "total = 2")
    end
    offense.correct(@corrector)

    assert_equal "total = 2", @corrector.process
  end
end
