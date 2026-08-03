require "test_helper"

class RuboCop::Cop::Callbacksystems::NoNilAtEndOfMethodTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoNilAtEndOfMethod

  test "registers offense for nil at end of method" do
    assert_offense <<~RUBY
      def process
        do_something
        nil
      end
    RUBY
  end

  test "registers offense for nil at end of class method" do
    assert_offense <<~RUBY
      def self.process
        do_something
        nil
      end
    RUBY
  end

  test "registers offense for nil after conditional" do
    assert_offense <<~RUBY
      def process
        if condition
          do_something
        end
        nil
      end
    RUBY
  end

  test "allows nil as only statement (intentional)" do
    assert_no_offense <<~RUBY
      def nothing
        nil
      end
    RUBY
  end

  test "allows method without nil at end" do
    assert_no_offense <<~RUBY
      def process
        do_something
      end
    RUBY
  end

  test "allows nil in conditional branches" do
    assert_no_offense <<~RUBY
      def process
        if condition
          nil
        else
          value
        end
      end
    RUBY
  end

  test "allows nil as return value in middle" do
    assert_no_offense <<~RUBY
      def process
        return nil unless valid?
        do_something
      end
    RUBY
  end

  test "allows empty method" do
    assert_no_offense <<~RUBY
      def process
      end
    RUBY
  end

  test "allows implicit return of method call" do
    assert_no_offense <<~RUBY
      def process
        calculate_result
      end
    RUBY
  end

  test "removes the trailing nil" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        do_something
        nil
      end
    RUBY
      def process
        do_something
      end
    CORRECTED
  end

  test "removes the trailing nil after a conditional" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        if condition
          do_something
        end
        nil
      end
    RUBY
      def process
        if condition
          do_something
        end
      end
    CORRECTED
  end

  test "removes the trailing nil in a one-line method" do
    assert_correction "def process; do_something; nil; end", "def process; do_something; end"
  end

  test "keeps a comment written above the trailing nil" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        def process
          do_something
          # keep this note
          nil
        end
      RUBY
        def process
          do_something
          # keep this note
        end
      CORRECTED
  end

  test "keeps the heredoc body written below the statement above the nil" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        def process
          wrap(<<~TEXT)
            hello
          TEXT
          nil
        end
      RUBY
        def process
          wrap(<<~TEXT)
            hello
          TEXT
        end
      CORRECTED
  end
end
