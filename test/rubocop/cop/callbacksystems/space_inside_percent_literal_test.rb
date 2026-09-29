require "test_helper"

class RuboCop::Cop::Callbacksystems::SpaceInsidePercentLiteralTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::SpaceInsidePercentLiteral

  test "registers offense for a symbol literal without spaces" do
    assert_offense <<~RUBY
      MUTATORS = %i[save update]
    RUBY
  end

  test "registers offense for a word literal without spaces" do
    assert_offense <<~RUBY
      NAMES = %w[alice bob]
    RUBY
  end

  test "registers offense for a literal missing only the closing space" do
    assert_offense <<~RUBY
      MUTATORS = %i[ save update]
    RUBY
  end

  test "registers offense for a literal missing only the opening space" do
    assert_offense <<~RUBY
      MUTATORS = %i[save update ]
    RUBY
  end

  test "registers offense for a literal padded with more than one space" do
    assert_offense <<~RUBY
      MUTATORS = %i[  save update  ]
    RUBY
  end

  test "registers offense for an interpolating literal without spaces" do
    assert_offense <<~'RUBY'
      NAMES = %W[a#{suffix} b]
    RUBY
  end

  test "registers offense for a literal delimited by parentheses" do
    assert_offense <<~RUBY
      MUTATORS = %i(save update)
    RUBY
  end

  test "allows a literal with a space inside each delimiter" do
    assert_no_offense <<~RUBY
      MUTATORS = %i[ save update ]
    RUBY
  end

  test "allows a literal holding a single element" do
    assert_no_offense <<~RUBY
      MUTATORS = %i[ save ]
    RUBY
  end

  test "allows a literal spanning several lines, where the breaks separate the elements" do
    assert_no_offense <<~RUBY
      MUTATORS = %i[
        save update
        destroy
      ]
    RUBY
  end

  test "allows an empty literal, which has nothing to separate" do
    assert_no_offense <<~RUBY
      MUTATORS = %i[]
    RUBY
  end

  test "allows a plain array literal, which another cop owns" do
    assert_no_offense <<~RUBY
      MUTATORS = [ :save, :update ]
    RUBY
  end

  test "adds the spaces a literal is missing" do
    assert_correction <<~RUBY, <<~CORRECTED
      MUTATORS = %i[save update]
    RUBY
      MUTATORS = %i[ save update ]
    CORRECTED
  end

  test "adds only the space that is missing" do
    assert_correction <<~RUBY, <<~CORRECTED
      MUTATORS = %i[ save update]
    RUBY
      MUTATORS = %i[ save update ]
    CORRECTED
  end

  test "collapses several spaces into one" do
    assert_correction <<~RUBY, <<~CORRECTED
      MUTATORS = %i[  save update   ]
    RUBY
      MUTATORS = %i[ save update ]
    CORRECTED
  end

  test "keeps the delimiters a literal was written with" do
    assert_correction <<~RUBY, <<~CORRECTED
      MUTATORS = %i(save update)
    RUBY
      MUTATORS = %i( save update )
    CORRECTED
  end
end
