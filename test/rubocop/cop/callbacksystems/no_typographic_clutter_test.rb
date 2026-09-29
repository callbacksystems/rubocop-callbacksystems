require "test_helper"

class RuboCop::Cop::Callbacksystems::NoTypographicClutterTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoTypographicClutter

  EM_DASH = 0x2014.chr(Encoding::UTF_8)
  EN_DASH = 0x2013.chr(Encoding::UTF_8)
  SMART_QUOTE = 0x201C.chr(Encoding::UTF_8)
  SMART_APOSTROPHE = 0x2019.chr(Encoding::UTF_8)
  ELLIPSIS = 0x2026.chr(Encoding::UTF_8)
  ZERO_WIDTH = 0x200B.chr(Encoding::UTF_8)
  ZERO_WIDTH_JOINER = 0x200D.chr(Encoding::UTF_8)
  NO_BREAK_SPACE = 0x00A0.chr(Encoding::UTF_8)
  NARROW_NO_BREAK_SPACE = 0x202F.chr(Encoding::UTF_8)
  SOFT_HYPHEN = 0x00AD.chr(Encoding::UTF_8)
  SMILING_FACE = 0x1F642.chr(Encoding::UTF_8)
  ARROW = 0x2192.chr(Encoding::UTF_8)
  BULLET = 0x2022.chr(Encoding::UTF_8)
  CHECK_MARK = 0x2713.chr(Encoding::UTF_8)
  GUILLEMET = 0x00AB.chr(Encoding::UTF_8)

  test "registers offense for an em-dash in a comment" do
    offenses = assert_offense(%(# name#{EM_DASH}required\nx = 1\n))

    assert_includes offenses.first.message, "U+2014"
  end

  test "registers offense for an en-dash in a comment" do
    assert_offense(%(# pages 1#{EN_DASH}9\nx = 1\n))
  end

  test "registers offense for a smart quote in a comment" do
    assert_offense(%(# says #{SMART_QUOTE}yes\nx = 1\n))
  end

  test "registers offense for a zero-width space in a comment" do
    assert_offense(%(# a#{ZERO_WIDTH}b\nx = 1\n))
  end

  test "registers offense for a double-hyphen em-dash substitute in a comment" do
    assert_offense(%(# name -- required\nx = 1\n))
  end

  test "registers offense for an invisible mark in a string, which compares unlike a space" do
    assert_offense(%(x = "a#{NO_BREAK_SPACE}b"\n))
  end

  test "registers offense for a soft hyphen in a string" do
    assert_offense(%(x = "a#{SOFT_HYPHEN}b"\n))
  end

  test "allows a smart quote in a string, which is the text a reader sees" do
    assert_no_offense(%(label = "said #{SMART_QUOTE}yes"\n))
  end

  test "allows an em-dash in a string" do
    assert_no_offense(%(label = "name#{EM_DASH}required"\n))
  end

  test "allows an ellipsis in a string" do
    assert_no_offense(%(label = "loading#{ELLIPSIS}"\n))
  end

  test "allows a zero-width joiner in a string, which joins an emoji sequence" do
    assert_no_offense(%(family = "a#{ZERO_WIDTH_JOINER}b"\n))
  end

  test "allows an arrow in a comment" do
    assert_no_offense(%(# input #{ARROW} output\nx = 1\n))
  end

  test "allows an arrow in a string" do
    assert_no_offense(%(x = "in #{ARROW} out"\n))
  end

  test "allows a bullet, a check mark, and a guillemet" do
    assert_no_offense(%(# #{BULLET} #{CHECK_MARK} #{GUILLEMET}\nx = "#{BULLET} #{CHECK_MARK} #{GUILLEMET}"\n))
  end

  test "allows a double hyphen in a string literal" do
    assert_no_offense(%(flag = "--watch"\n))
  end

  test "allows a double hyphen in a directive, whose spelling belongs to RuboCop" do
    assert_no_offense(%(# rubocop:disable Metrics/AbcSize -- the guard reads worse than the branch\nx = 1\n))
  end

  test "allows the double hyphen in an RDoc directive" do
    assert_no_offense("#--\ndef implementation_detail; end\n#++\n")
  end

  test "reports distinct clutter at its exact locations in the same comment" do
    offenses = assert_offense("# bad \u201Cquote\u201D -- punctuation -- again\nvalue = 1\n", count: 4)

    assert_equal [ "\u201C", "\u201D", "--", "--" ], offenses.map { it.location.source }
  end

  test "rewrites every correctable character in one pass" do
    assert_correction \
      %(# it#{SMART_APOSTROPHE}s #{SMART_QUOTE}loading#{ELLIPSIS}\n),
      %(# it's "loading...\n)
  end

  test "uses character offsets after a multibyte code point" do
    offenses = assert_offense(%(label = "#{SMILING_FACE}a#{NO_BREAK_SPACE}b#{NARROW_NO_BREAK_SPACE}c"\n), count: 2)

    assert_equal [ NO_BREAK_SPACE, NARROW_NO_BREAK_SPACE ], offenses.map { it.location.source }
  end

  test "finds and rewrites invisible marks in a static heredoc body" do
    assert_correction \
      <<~RUBY,
        label = <<~TEXT
          one#{NO_BREAK_SPACE}two#{NARROW_NO_BREAK_SPACE}three
        TEXT
      RUBY
      <<~RUBY
        label = <<~TEXT
          one two three
        TEXT
      RUBY
  end

  test "allows ASCII-only source" do
    assert_no_offense(%(# a normal comment\nlabel = "plain string"\n))
  end

  test "rewrites an ellipsis in a comment to three dots" do
    assert_correction(%(# loading#{ELLIPSIS}\n), %(# loading...\n))
  end

  test "rewrites a smart apostrophe in a comment to a straight one" do
    assert_correction(%(# it#{SMART_APOSTROPHE}s ready\nx = 1\n), %(# it's ready\nx = 1\n))
  end

  test "deletes a zero-width space in a comment" do
    assert_correction(%(# a#{ZERO_WIDTH}b\nx = 1\n), %(# ab\nx = 1\n))
  end

  test "rewrites a non-breaking space inside a string to a plain space" do
    assert_correction(%(x = "a#{NO_BREAK_SPACE}b"\n), %(x = "a b"\n))
  end

  test "leaves an em-dash for a human to map to ASCII" do
    assert_correction(%(# a#{EM_DASH}b\nx = 1\n), %(# a#{EM_DASH}b\nx = 1\n))
  end
end
