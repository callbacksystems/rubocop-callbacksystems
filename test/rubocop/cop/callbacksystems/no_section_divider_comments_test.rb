require "test_helper"

class RuboCop::Cop::Callbacksystems::NoSectionDividerCommentsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoSectionDividerComments

  LIGHT_HORIZONTAL = 0x2500.chr(Encoding::UTF_8)
  HEAVY_HORIZONTAL = 0x2501.chr(Encoding::UTF_8)
  DOUBLE_HORIZONTAL = 0x2550.chr(Encoding::UTF_8)

  test "allows a regular comment" do
    assert_no_offense <<~RUBY
      # a regular comment
      value = 1
    RUBY
  end

  test "allows a TODO comment" do
    assert_no_offense <<~RUBY
      # TODO: fix this
      value = 1
    RUBY
  end

  test "allows a comment with a single dash" do
    assert_no_offense <<~RUBY
      # - item one
      value = 1
    RUBY
  end

  test "allows the RDoc directives that hide and resume documentation" do
    assert_no_offense <<~RUBY
      #--
      def implementation_detail; end
      #++
    RUBY
  end

  test "registers offense for an equals divider" do
    offenses = assert_offense <<~RUBY
      # =============
      value = 1
    RUBY
    assert_includes offenses.first.message, "add no information"
  end

  test "registers offense for a dash divider" do
    assert_offense <<~RUBY
      # -------
      value = 1
    RUBY
  end

  test "registers offense for a box-drawing divider" do
    assert_offense(%(# #{LIGHT_HORIZONTAL * 12}\nvalue = 1\n))
  end

  test "registers offense for a wrapped divider title" do
    offenses = assert_offense <<~RUBY
      # ===== Section ======
      value = 1
    RUBY
    assert_includes offenses.first.message, "inner text"
  end

  test "registers offense for a wrapped box-drawing title" do
    assert_offense(%(# #{HEAVY_HORIZONTAL * 3} Getters #{HEAVY_HORIZONTAL * 3}\nvalue = 1\n))
  end

  test "removes a pure divider line" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # =============
      value = 1
    RUBY
      value = 1
    CORRECTED
  end

  test "removes a trailing pure divider but keeps the code" do
    assert_correction("value = 1 # -------\n", "value = 1\n")
  end

  test "strips decorations from a wrapped divider" do
    assert_correction(<<~RUBY, <<~CORRECTED)
      # ===== Section =====
      value = 1
    RUBY
      # Section
      value = 1
    CORRECTED
  end

  test "strips decorations from a wrapped box-drawing divider" do
    assert_correction %(# #{DOUBLE_HORIZONTAL * 3} Setup #{DOUBLE_HORIZONTAL * 3}\nvalue = 1\n),
      "# Setup\nvalue = 1\n"
  end
end
