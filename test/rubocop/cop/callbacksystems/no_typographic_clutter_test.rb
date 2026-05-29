require "test_helper"

class RuboCop::Cop::Callbacksystems::NoTypographicClutterTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoTypographicClutter

  EM_DASH = 0x2014.chr(Encoding::UTF_8)
  SMART_QUOTE = 0x201C.chr(Encoding::UTF_8)
  ZERO_WIDTH = 0x200B.chr(Encoding::UTF_8)
  SMART_APOSTROPHE = 0x2019.chr(Encoding::UTF_8)
  ELLIPSIS = 0x2026.chr(Encoding::UTF_8)
  NO_BREAK_SPACE = 0x00A0.chr(Encoding::UTF_8)

  test "registers offense for an em-dash in a comment" do
    offenses = assert_offense(%(# name#{EM_DASH}required\nx = 1\n))
    assert_includes offenses.first.message, "U+2014"
  end

  test "registers offense for a smart quote in a string literal" do
    assert_offense(%(label = "a#{SMART_QUOTE}b"\n))
  end

  test "registers offense for a zero-width space" do
    assert_offense(%(value = "a#{ZERO_WIDTH}b"\n))
  end

  test "registers offense for a double-hyphen em-dash substitute in a comment" do
    assert_offense(%(# name -- required\nx = 1\n))
  end

  test "allows a double hyphen in a string literal" do
    assert_no_offense(%(flag = "--watch"\n))
  end

  test "allows ASCII-only source" do
    assert_no_offense(%(# a normal comment\nlabel = "plain string"\n))
  end

  test "rewrites an ellipsis in a comment to three dots" do
    assert_correction(%(# loading#{ELLIPSIS}\n), %(# loading...\n))
  end

  test "rewrites a smart apostrophe inside a double-quoted string" do
    assert_correction(%(x = "it#{SMART_APOSTROPHE}s"\n), %(x = "it's"\n))
  end

  test "rewrites a smart double quote inside a single-quoted string" do
    assert_correction(%(x = 'a#{SMART_QUOTE}b'\n), %(x = 'a"b'\n))
  end

  test "deletes a zero-width space inside a string" do
    assert_correction(%(value = "a#{ZERO_WIDTH}b"\n), %(value = "ab"\n))
  end

  test "rewrites a non-breaking space inside a string to a plain space" do
    assert_correction(%(x = "a#{NO_BREAK_SPACE}b"\n), %(x = "a b"\n))
  end

  test "leaves a smart quote that would close its own string delimiter" do
    assert_correction(%(x = "a#{SMART_QUOTE}b"\n), %(x = "a#{SMART_QUOTE}b"\n))
  end

  test "leaves an em-dash for a human to map to ASCII" do
    assert_correction(%(# a#{EM_DASH}b\nx = 1\n), %(# a#{EM_DASH}b\nx = 1\n))
  end
end
